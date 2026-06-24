#!/usr/bin/env bash
# Keyboard navigation for the accel-menu eww window.
# Usage: nav.sh <init|move up|move down|confirm|apply <profile>|cancel>
set -euo pipefail

cfg="$HOME/.config/eww"
EWW=(eww --config "$cfg")
sel_file="$HOME/.cache/accel_selected"
state_file="$HOME/.cache/accel_profile"

# Order of profiles for navigation (extend here if you add more).
profiles=(adaptive custom)

current_sel() { cat "$sel_file" 2>/dev/null || echo "${profiles[0]}"; }

set_sel() {
    echo "$1" > "$sel_file"
    "${EWW[@]}" update selected="$1" >/dev/null 2>&1 || true
}

# Move the highlight by an offset (wraps around the profiles list).
move() {
    local offset="$1" cur i n idx
    cur="$(current_sel)"
    n=${#profiles[@]}
    idx=0
    for i in "${!profiles[@]}"; do
        [ "${profiles[$i]}" = "$cur" ] && idx=$i
    done
    idx=$(( (idx + offset + n) % n ))
    set_sel "${profiles[$idx]}"
}

close_menu() {
    hyprctl eval 'hl.dispatch(hl.dsp.submap("reset"))' >/dev/null 2>&1 || true
    "${EWW[@]}" close accel-menu >/dev/null 2>&1 || true
}

cmd="${1:-}"
case "$cmd" in
    init)    set_sel "$(cat "$state_file" 2>/dev/null || echo "${profiles[0]}")" ;;
    move)    case "${2:-down}" in up) move -1 ;; *) move 1 ;; esac ;;
    confirm) "$cfg/scripts/set-accel.sh" "$(current_sel)"; close_menu ;;
    apply)   set_sel "${2:?missing profile}"; "$cfg/scripts/set-accel.sh" "$2"; close_menu ;;
    cancel)  close_menu ;;
    *)       echo "nav.sh: unknown command '$cmd'" >&2; exit 1 ;;
esac
