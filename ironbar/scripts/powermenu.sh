#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
#  Power menu actions. Closes the popup first, then acts.
#  `top` is the bar name and `power` the custom module name in config.yaml.
# ─────────────────────────────────────────────────────────────────────
set -uo pipefail

close() { ironbar bar top hide-popup >/dev/null 2>&1 || true; }

case "${1:-}" in
    lock)     close; loginctl lock-session ;;
    logout)   close; hyprctl dispatch exit ;;
    suspend)  close; systemctl suspend ;;
    reboot)   close; systemctl reboot ;;
    shutdown) close; systemctl poweroff ;;
    *) close ;;
esac
