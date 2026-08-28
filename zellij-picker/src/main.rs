//! zellij-picker — a GTK4 layer-shell picker for zellij sessions.
//!
//! Layout, top to bottom: a folder box (type a path, Tab completes it, Enter
//! creates it if needed and opens a session there), a search bar, and the
//! session list. Typing goes to the search bar unless the folder box is the
//! selected item, in which case it goes there.

mod complete;
mod sessions;

use std::cell::RefCell;
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::rc::Rc;

use gtk4 as gtk;

use gtk::gdk::{Display, Key, ModifierType};
use gtk::gio::ApplicationFlags;
use gtk::glib::{self, Propagation};
use gtk::prelude::*;
use gtk::{
    Align, Application, ApplicationWindow, CssProvider, EventControllerKey, Label, ListBox,
    ListBoxRow, Orientation, PropagationPhase, ScrolledWindow, SelectionMode,
};
use gtk4_layer_shell::{KeyboardMode, Layer, LayerShell};

use sessions::Session;

const APP_ID: &str = "dev.inti.zellij-picker";
const TERMINAL: &str = "ghostty";
const WINDOW_CLASS: &str = "--class=com.zellij.ghostty";

fn main() -> glib::ExitCode {
    let app = Application::builder()
        .application_id(APP_ID)
        .flags(ApplicationFlags::NON_UNIQUE)
        .build();

    app.connect_startup(|_| {
        let provider = CssProvider::new();
        provider.load_from_string(include_str!("style.css"));
        if let Some(display) = Display::default() {
            // Above PRIORITY_USER: the GTK theme installed in
            // ~/.config/gtk-4.0/gtk.css (currently Orchis-Pink-Dark) loads at
            // USER priority and would otherwise repaint the list itself.
            gtk::style_context_add_provider_for_display(
                &display,
                &provider,
                gtk::STYLE_PROVIDER_PRIORITY_USER + 1,
            );
        }
    });
    app.connect_activate(build_ui);
    app.run()
}

/// A folder's session name: its last component, as the README promises.
/// `/` has none, and zellij rejects an empty name, so fall back to something.
fn session_name(path: &Path) -> String {
    path.file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_else(|| "zellij".into())
}

/// Everything the callbacks need to reach.
struct Ui {
    window: ApplicationWindow,
    folder: gtk::Entry,
    hint: Label,
    search: gtk::Entry,
    list: ListBox,
    rows: RefCell<Vec<ListBoxRow>>,
    sessions: RefCell<Vec<Session>>,
    home: PathBuf,
    attach_bin: PathBuf,
}

fn build_ui(app: &Application) {
    let home = PathBuf::from(std::env::var("HOME").unwrap_or_else(|_| "/".into()));

    let window = ApplicationWindow::builder()
        .application(app)
        .default_width(640)
        .build();
    window.init_layer_shell();
    window.set_layer(Layer::Overlay);
    window.set_keyboard_mode(KeyboardMode::Exclusive);
    window.set_namespace(Some("zellij-picker"));

    let folder = gtk::Entry::builder()
        .placeholder_text("New session in folder…")
        .build();
    folder.add_css_class("folder");

    let hint = Label::builder()
        .xalign(0.0)
        .visible(false)
        .ellipsize(gtk::pango::EllipsizeMode::End)
        .build();
    hint.add_css_class("hint");

    let search = gtk::Entry::builder().placeholder_text("Search…").build();
    search.add_css_class("search");

    let list = ListBox::new();
    list.set_selection_mode(SelectionMode::Single);
    list.set_activate_on_single_click(true);

    let scroller = ScrolledWindow::builder()
        .child(&list)
        .hscrollbar_policy(gtk::PolicyType::Never)
        .max_content_height(340)
        .propagate_natural_height(true)
        .build();

    let root = gtk::Box::new(Orientation::Vertical, 12);
    root.add_css_class("root");
    root.append(&folder);
    root.append(&hint);
    root.append(&search);
    root.append(&scroller);
    window.set_child(Some(&root));

    let ui = Rc::new(Ui {
        window: window.clone(),
        folder: folder.clone(),
        hint: hint.clone(),
        search: search.clone(),
        list: list.clone(),
        rows: RefCell::new(Vec::new()),
        sessions: RefCell::new(Vec::new()),
        attach_bin: home.join("bin/zellij-attach"),
        home,
    });

    ui.reload();

    // Typing filters the list; the first match becomes the selection.
    {
        let ui = ui.clone();
        search.connect_changed(move |_| ui.apply_filter());
    }

    // A fresh completion attempt starts from a clean hint.
    {
        let ui = ui.clone();
        folder.connect_changed(move |_| ui.hint.set_visible(false));
    }

    // Clicking a row opens it.
    {
        let ui = ui.clone();
        list.connect_row_activated(move |_, row| ui.attach_row(row.index(), false));
    }

    // Clicking into the folder box makes it the selected item.
    {
        let ui = ui.clone();
        let focus = gtk::EventControllerFocus::new();
        focus.connect_enter(move |_| ui.list.unselect_all());
        folder.add_controller(focus);
    }

    let keys = EventControllerKey::new();
    keys.set_propagation_phase(PropagationPhase::Capture);
    {
        let ui = ui.clone();
        keys.connect_key_pressed(move |_, key, _, state| ui.on_key(key, state));
    }
    window.add_controller(keys);

    window.present();
    // Settle focus and selection once GTK has finished handing out initial
    // focus: it gives the folder box the first go, which clears the selection.
    {
        let ui = ui.clone();
        glib::idle_add_local_once(move || {
            // The search bar owns the keyboard until the folder box is selected.
            GtkWindowExt::set_focus(&ui.window, Some(&ui.search));
            ui.apply_filter();
        });
    }
}

impl Ui {
    /// Is the folder box the selected item?
    ///
    /// GtkEntry delegates focus to its inner text widget, so `has_focus()` on
    /// the entry itself is always false — ask for focus *within* instead.
    fn folder_active(&self) -> bool {
        self.folder.state_flags().contains(gtk::StateFlags::FOCUS_WITHIN)
    }

    fn on_key(&self, key: Key, state: ModifierType) -> Propagation {
        let alt = state.contains(ModifierType::ALT_MASK);
        match key {
            Key::Escape => {
                self.window.close();
                Propagation::Stop
            }
            Key::Tab | Key::ISO_Left_Tab => {
                if self.folder_active() {
                    self.complete_folder();
                } else {
                    self.focus_folder();
                }
                Propagation::Stop
            }
            Key::Down => {
                if self.folder_active() {
                    self.focus_list();
                } else {
                    self.step(1);
                }
                Propagation::Stop
            }
            Key::Up => {
                if !self.folder_active() && !self.step(-1) {
                    self.focus_folder();
                }
                Propagation::Stop
            }
            Key::Return | Key::KP_Enter => {
                if self.folder_active() {
                    self.open_folder();
                } else if let Some(row) = self.list.selected_row() {
                    self.attach_row(row.index(), alt);
                }
                Propagation::Stop
            }
            Key::k | Key::K if alt => {
                self.remove_selected();
                Propagation::Stop
            }
            _ => Propagation::Proceed,
        }
    }

    // ── list ─────────────────────────────────────────────────────────────

    fn reload(&self) {
        while let Some(child) = self.list.first_child() {
            self.list.remove(&child);
        }
        self.rows.borrow_mut().clear();

        let found = sessions::list();
        for session in &found {
            let row = ListBoxRow::new();
            let line = gtk::Box::new(Orientation::Horizontal, 10);

            let name = Label::new(Some(&session.name));
            name.set_xalign(0.0);
            name.add_css_class("name");

            let meta = Label::new(Some(&format!("{} · {}", session.state.label(), session.age)));
            meta.add_css_class("meta");
            meta.set_halign(Align::End);
            meta.set_hexpand(true);

            line.append(&name);
            line.append(&meta);
            row.set_child(Some(&line));
            self.list.append(&row);
            self.rows.borrow_mut().push(row);
        }
        *self.sessions.borrow_mut() = found;
        self.apply_filter();
    }

    fn matches(&self, index: usize, query: &str) -> bool {
        self.sessions
            .borrow()
            .get(index)
            .map(|s| s.name.to_lowercase().contains(query))
            .unwrap_or(false)
    }

    /// Hide rows that do not match the search text, then select the first hit.
    fn apply_filter(&self) {
        let query = self.search.text().to_lowercase();
        let rows = self.rows.borrow();
        let mut first: Option<ListBoxRow> = None;
        for (i, row) in rows.iter().enumerate() {
            let visible = self.matches(i, &query);
            row.set_visible(visible);
            if visible && first.is_none() {
                first = Some(row.clone());
            }
        }
        drop(rows);
        match (first, self.folder_active()) {
            (Some(row), false) => self.list.select_row(Some(&row)),
            _ => self.list.unselect_all(),
        }
    }

    /// Move the selection by `delta` over the visible rows.
    /// Returns false when there was nowhere to go.
    fn step(&self, delta: i32) -> bool {
        let rows = self.rows.borrow();
        let visible: Vec<&ListBoxRow> = rows.iter().filter(|r| r.is_visible()).collect();
        if visible.is_empty() {
            return false;
        }
        let current = self
            .list
            .selected_row()
            .and_then(|sel| visible.iter().position(|r| r.index() == sel.index()));
        let next = match (current, delta) {
            (Some(i), d) => i as i32 + d,
            (None, d) if d > 0 => 0,
            (None, _) => visible.len() as i32 - 1,
        };
        if next < 0 || next as usize >= visible.len() {
            return false;
        }
        let row = visible[next as usize];
        self.list.select_row(Some(row));
        row.grab_focus();
        self.search.grab_focus();
        true
    }

    fn focus_folder(&self) {
        self.list.unselect_all();
        self.folder.grab_focus();
        // grab_focus selects the whole path; put the caret at the end so
        // typing extends what is there instead of replacing it.
        self.folder.set_position(-1);
    }

    fn focus_list(&self) {
        self.search.grab_focus();
        if self.list.selected_row().is_none() {
            self.step(1);
        }
    }

    // ── actions ──────────────────────────────────────────────────────────

    fn attach_row(&self, index: i32, keep: bool) {
        let name = match self.sessions.borrow().get(index as usize) {
            Some(session) => session.name.clone(),
            None => return,
        };
        let mut args: Vec<String> = vec![WINDOW_CLASS.into(), "-e".into()];
        args.push(self.attach_bin.to_string_lossy().into_owned());
        if keep {
            args.push("--keep".into());
        }
        args.push(name);
        self.spawn(&args);
    }

    /// Create the folder if it is missing and open a session in it.
    fn open_folder(&self) {
        let typed = self.folder.text().to_string();
        if typed.trim().is_empty() {
            return;
        }
        let path = complete::resolve(&typed, &self.home);
        if std::fs::create_dir_all(&path).is_err() {
            self.folder.add_css_class("error");
            return;
        }
        let args: Vec<String> = vec![
            WINDOW_CLASS.into(),
            format!("--working-directory={}", path.display()),
            "-e".into(),
            self.attach_bin.to_string_lossy().into_owned(),
            session_name(&path),
        ];
        self.spawn(&args);
    }

    fn complete_folder(&self) {
        let typed = self.folder.text().to_string();
        let result = complete::complete(&typed, &self.home);
        if result.text != typed {
            self.folder.set_text(&result.text);
            self.folder.set_position(-1);
        }
        if result.candidates.is_empty() {
            self.hint.set_visible(false);
        } else {
            self.hint.set_text(&result.candidates.join("   "));
            self.hint.set_visible(true);
        }
    }

    fn remove_selected(&self) {
        let index = match self.list.selected_row() {
            Some(row) => row.index() as usize,
            None => return,
        };
        let session = match self.sessions.borrow().get(index) {
            Some(session) => session.clone(),
            None => return,
        };
        sessions::remove(&session);
        self.reload();
    }

    fn spawn(&self, args: &[String]) {
        let _ = Command::new(TERMINAL)
            .args(args)
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .process_group(0)
            .spawn();
        self.window.close();
    }
}
