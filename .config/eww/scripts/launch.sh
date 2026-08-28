#!/usr/bin/env bash
# Toggle the mouse-acceleration profile picker window (keyboard-driven).
set -euo pipefail

cfg="$HOME/.config/eww"
EWW=(eww --config "$cfg")

# Ensure the daemon is running (no-op if it already is).
"${EWW[@]}" daemon >/dev/null 2>&1 || true

if "${EWW[@]}" active-windows 2>/dev/null | grep -q '^accel-menu:'; then
    # Already open -> close it and leave the keymap.
    hyprctl eval 'hl.dispatch(hl.dsp.submap("reset"))' >/dev/null 2>&1 || true
    "${EWW[@]}" close accel-menu >/dev/null 2>&1 || true
else
    "${EWW[@]}" open accel-menu
    "$cfg/scripts/nav.sh" init                                   # highlight the active profile
    hyprctl eval 'hl.dispatch(hl.dsp.submap("accel"))' >/dev/null 2>&1 || true  # enter modal keymap
fi
