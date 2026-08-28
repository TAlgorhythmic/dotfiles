//! Shell-style filesystem completion for the folder box.
//!
//! Kept free of GTK so the interesting logic is unit-testable.

use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Default, PartialEq, Eq)]
pub struct Completion {
    /// The input after completing as far as it unambiguously can.
    pub text: String,
    /// Directory names that matched, for the hint line. Empty when unambiguous.
    pub candidates: Vec<String>,
}

/// Turn what the user typed into a real path.
///
/// `~/x` and `/x` mean what they say; anything else is taken as relative to
/// home, so typing `Code/foo` lands in `~/Code/foo`.
pub fn resolve(input: &str, home: &Path) -> PathBuf {
    let input = input.trim();
    if input.is_empty() {
        return home.to_path_buf();
    }
    if let Some(rest) = input.strip_prefix("~/") {
        return home.join(rest);
    }
    if input == "~" {
        return home.to_path_buf();
    }
    if input.starts_with('/') {
        return PathBuf::from(input);
    }
    home.join(input)
}

/// Complete `input` against the filesystem, shell style: extend as far as the
/// candidates agree, add a trailing slash when only one directory matches.
pub fn complete(input: &str, home: &Path) -> Completion {
    let (dir_text, prefix) = match input.rfind('/') {
        Some(i) => (&input[..=i], &input[i + 1..]),
        None => ("", input),
    };
    let base = resolve(dir_text, home);

    let mut names: Vec<String> = match fs::read_dir(&base) {
        Ok(entries) => entries
            .filter_map(Result::ok)
            .filter(|e| e.path().is_dir())
            .map(|e| e.file_name().to_string_lossy().into_owned())
            .filter(|n| prefix.starts_with('.') || !n.starts_with('.'))
            .collect(),
        Err(_) => return Completion { text: input.to_string(), candidates: Vec::new() },
    };

    let mut matched: Vec<String> = names.iter().filter(|n| n.starts_with(prefix)).cloned().collect();
    if matched.is_empty() {
        let lower = prefix.to_lowercase();
        matched = names
            .iter()
            .filter(|n| n.to_lowercase().starts_with(&lower))
            .cloned()
            .collect();
    }
    names.clear();

    if matched.is_empty() {
        return Completion { text: input.to_string(), candidates: Vec::new() };
    }
    matched.sort();

    let stem = common_prefix(&matched);
    let mut text = format!("{dir_text}{stem}");
    if matched.len() == 1 {
        text.push('/');
        return Completion { text, candidates: Vec::new() };
    }
    Completion { text, candidates: matched }
}

fn common_prefix(items: &[String]) -> String {
    let first = match items.first() {
        Some(f) => f,
        None => return String::new(),
    };
    let mut end = first.len();
    for other in &items[1..] {
        let shared = first
            .char_indices()
            .zip(other.chars())
            .take_while(|((_, a), b)| a == b)
            .map(|((i, a), _)| i + a.len_utf8())
            .last()
            .unwrap_or(0);
        end = end.min(shared);
    }
    first[..end].to_string()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    /// A throwaway tree: <tmp>/{Code/{arcc,arcane,scop},.hidden}
    fn fixture(tag: &str) -> PathBuf {
        let root = std::env::temp_dir().join(format!("zellij-picker-test-{tag}"));
        let _ = fs::remove_dir_all(&root);
        for dir in ["Code/arcc", "Code/arcane", "Code/scop", ".hidden"] {
            fs::create_dir_all(root.join(dir)).unwrap();
        }
        fs::write(root.join("Code/notadir.txt"), "x").unwrap();
        root
    }

    #[test]
    fn completes_a_unique_directory_and_adds_a_slash() {
        let home = fixture("unique");
        assert_eq!(complete("Cod", &home).text, "Code/");
    }

    #[test]
    fn stops_at_the_common_prefix_and_reports_candidates() {
        let home = fixture("ambiguous");
        let c = complete("Code/arc", &home);
        assert_eq!(c.text, "Code/arc");
        assert_eq!(c.candidates, vec!["arcane".to_string(), "arcc".to_string()]);
    }

    #[test]
    fn extends_to_the_longest_shared_stem() {
        let home = fixture("stem");
        // "a" -> both arcane and arcc share "arc"
        assert_eq!(complete("Code/a", &home).text, "Code/arc");
    }

    #[test]
    fn lists_a_directory_when_the_prefix_is_empty() {
        let home = fixture("listing");
        let c = complete("Code/", &home);
        assert_eq!(c.text, "Code/");
        assert_eq!(c.candidates.len(), 3);
    }

    #[test]
    fn ignores_files_and_hidden_dirs() {
        let home = fixture("hidden");
        assert!(complete("Code/nota", &home).candidates.is_empty());
        assert_eq!(complete("Code/nota", &home).text, "Code/nota");
        assert_eq!(complete(".hid", &home).text, ".hidden/");
    }

    #[test]
    fn falls_back_to_case_insensitive_matching() {
        let home = fixture("case");
        assert_eq!(complete("cod", &home).text, "Code/");
    }

    #[test]
    fn leaves_unmatched_input_alone() {
        let home = fixture("nomatch");
        assert_eq!(complete("zzz", &home).text, "zzz");
    }

    #[test]
    fn resolves_the_three_path_flavours() {
        let home = Path::new("/home/x");
        assert_eq!(resolve("", home), PathBuf::from("/home/x"));
        assert_eq!(resolve("~/a", home), PathBuf::from("/home/x/a"));
        assert_eq!(resolve("/tmp/a", home), PathBuf::from("/tmp/a"));
        assert_eq!(resolve("a/b", home), PathBuf::from("/home/x/a/b"));
    }
}
