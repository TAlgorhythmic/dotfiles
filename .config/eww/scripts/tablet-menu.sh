#!/usr/bin/env bash
# Toggle the tablet audio control window.
set -euo pipefail

EWW=(eww --config "$HOME/.config/eww")

"${EWW[@]}" daemon >/dev/null 2>&1 || true

if "${EWW[@]}" active-windows 2>/dev/null | grep -q '^tablet-audio:'; then
    "${EWW[@]}" close tablet-audio >/dev/null 2>&1 || true
else
    "${EWW[@]}" open tablet-audio
    "${EWW[@]}" update tablet-volume="$("$HOME/bin/tablet-audio" get-volume)"
fi
