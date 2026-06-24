#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
#  Active window title (deflisten) — re-queried on focus/close/etc.
# ─────────────────────────────────────────────────────────────────────
set -uo pipefail

sig="${HYPRLAND_INSTANCE_SIGNATURE:-}"
sock="${XDG_RUNTIME_DIR}/hypr/${sig}/.socket2.sock"

emit() { hyprctl -j activewindow 2>/dev/null | jq -r '.title // ""' 2>/dev/null; }

emit
[ -S "$sock" ] || exit 0

socat -U - "UNIX-CONNECT:${sock}" 2>/dev/null | while read -r line; do
    case "$line" in
        activewindow\>\>*|closewindow*|openwindow*|fullscreen*|focusedmon*|workspace*|windowtitle*)
            emit ;;
    esac
done
