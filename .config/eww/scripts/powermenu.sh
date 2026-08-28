#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
#  Power menu actions. Closes the menu first, then acts.
# ─────────────────────────────────────────────────────────────────────
set -uo pipefail

eww="$(command -v eww)"
cfg="$HOME/.config/eww"
close() { "$eww" --config "$cfg" close powermenu 2>/dev/null || true; }

case "${1:-}" in
    lock)     close; loginctl lock-session ;;
    logout)   close; hyprctl dispatch exit ;;
    suspend)  close; systemctl suspend ;;
    reboot)   close; systemctl reboot ;;
    shutdown) close; systemctl poweroff ;;
    *) close ;;
esac
