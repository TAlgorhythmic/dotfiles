# zellij-picker

A GTK4 layer-shell picker for zellij sessions, bound to `SUPER+P` in Hyprland.

```
┌──────────────────────────────────────┐
│ New session in folder…               │  ← folder box (Tab completes paths)
│ Search…                              │  ← search bar (has the keyboard by default)
│ luckyhearts            exited · 18d  │
│ transcendence          exited · 13d  │
└──────────────────────────────────────┘
```

## Keys

| Key | Action |
| --- | --- |
| type | filters the session list |
| `Tab` | from the list: jump to the folder box. In the folder box: complete the path |
| `Up` / `Down` | move the selection; `Up` past the top row selects the folder box |
| `Enter` | on a session: attach in a new ghostty window. In the folder box: create the folder if needed and open a session there |
| `Alt+Enter` | attach, but leave the session running when you detach |
| `Alt+K` | kill a running session / drop an exited one, then refresh |
| `Esc` | close |

Whichever of the two boxes has focus receives typing, so the folder box only
takes input once it is selected.

Paths in the folder box are relative to `$HOME` unless they start with `/` or
`~`, so `Code/foo` means `~/Code/foo`. The session is named after the folder.

## How sessions are opened

`ghostty -e ~/bin/zellij-attach <session>`, which attaches and then
**kills the session when you detach**, closing the window with it. Pass
`--keep` (via `Alt+Enter`) to detach and leave it running.

Note: on zellij 0.45 `kill-session` also deletes the session's serialized
snapshot, so a killed session does not linger as `EXITED - attach to resurrect`.

## Build

```sh
cargo build --release      # setup-arch.sh copies target/release/zellij-picker to ~/bin
cargo test                 # path completion + session parsing
```

The stylesheet is registered above `PRIORITY_USER` because the Graphite theme
in `~/.config/gtk-4.0/gtk.css` loads at user priority and would otherwise
repaint the list in its own light palette.
