//! Talking to the zellij CLI: listing, killing and deleting sessions.

use std::process::Command;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum State {
    Running,
    Exited,
}

impl State {
    pub fn label(self) -> &'static str {
        match self {
            State::Running => "running",
            State::Exited => "exited",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Session {
    pub name: String,
    pub state: State,
    /// Coarse age, e.g. "18days" — the first component zellij prints.
    pub age: String,
}

/// Parse one line of `zellij list-sessions -n`, e.g.
/// `scop [Created 11days 6h 39m 1s ago] (EXITED - attach to resurrect)`
pub fn parse_line(line: &str) -> Option<Session> {
    let line = line.trim();
    if line.is_empty() {
        return None;
    }
    let name = line.split_whitespace().next()?.to_string();

    let age = line
        .split_once("[Created ")
        .and_then(|(_, rest)| rest.split_once(" ago]"))
        .map(|(age, _)| age.split_whitespace().next().unwrap_or("").to_string())
        .unwrap_or_default();

    let state = if line.contains("EXITED") {
        State::Exited
    } else {
        State::Running
    };

    Some(Session { name, state, age })
}

/// Running sessions first, then the exited (resurrectable) ones.
pub fn list() -> Vec<Session> {
    let out = match Command::new("zellij").args(["list-sessions", "-n"]).output() {
        Ok(out) => out,
        Err(_) => return Vec::new(),
    };
    let text = String::from_utf8_lossy(&out.stdout);
    let mut sessions: Vec<Session> = text.lines().filter_map(parse_line).collect();
    sessions.sort_by_key(|s| s.state == State::Exited);
    sessions
}

/// Kill a running session, or drop an exited one from the resurrect list.
///
/// Note: on zellij 0.45 `kill-session` also deletes the session's serialized
/// snapshot, so a killed session does not linger as "EXITED".
pub fn remove(session: &Session) {
    let verb = match session.state {
        State::Running => "kill-session",
        State::Exited => "delete-session",
    };
    let _ = Command::new("zellij").arg(verb).arg(&session.name).status();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_a_running_session() {
        let s = parse_line("notes [Created 5s ago]").unwrap();
        assert_eq!(s.name, "notes");
        assert_eq!(s.state, State::Running);
        assert_eq!(s.age, "5s");
    }

    #[test]
    fn parses_an_exited_session() {
        let s =
            parse_line("scop [Created 11days 6h 39m 1s ago] (EXITED - attach to resurrect)").unwrap();
        assert_eq!(s.name, "scop");
        assert_eq!(s.state, State::Exited);
        assert_eq!(s.age, "11days");
    }

    #[test]
    fn ignores_blank_lines() {
        assert!(parse_line("   ").is_none());
    }

    #[test]
    fn survives_a_line_without_the_created_marker() {
        let s = parse_line("weird").unwrap();
        assert_eq!(s.name, "weird");
        assert_eq!(s.age, "");
    }
}
