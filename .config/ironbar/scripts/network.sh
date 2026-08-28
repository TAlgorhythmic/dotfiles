#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
#  Network status (polled) → Pango markup for the bar label.
#  DRIVER-SAFE BY DESIGN:
#    • connectivity comes from sysfs operstate (instant, no radio access)
#    • SSID is read from iwd's *cached* D-Bus state — NO scan, and the
#      whole read is wrapped in `timeout 1` as a hard safety net.
#    • never calls iwctl / iw / nmcli, never triggers the slow adapter.
# ─────────────────────────────────────────────────────────────────────
set -uo pipefail

ACCENT="#F06292"
FG="#ffffff"
DANGER="#F44336"

# Pango-escape (SSIDs may legitimately contain & or <).
esc() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

up()   { printf '<span foreground="%s" size="larger">%s</span> <span foreground="%s" size="smaller">%s</span>\n' \
             "$ACCENT" "$1" "$FG" "$(esc "$2")"; }
down() { printf '<span foreground="%s" size="larger">%s</span> <span foreground="%s" size="smaller">%s</span>\n' \
             "$DANGER" "$1" "$DANGER" "$2"; }

# ── Ethernet first (pure sysfs) ──────────────────────────────────────
for i in /sys/class/net/e*; do
    [ -e "$i" ] || continue
    if [ "$(cat "$i/operstate" 2>/dev/null)" = up ]; then
        up "󰈀" "Ethernet"
        exit 0
    fi
done

# ── Wi-Fi adapter present? ───────────────────────────────────────────
wdev=""
for i in /sys/class/net/wl*; do [ -e "$i" ] && wdev=$(basename "$i") && break; done
if [ -z "$wdev" ]; then
    down "󰤭" "Off"
    exit 0
fi

state=$(cat "/sys/class/net/$wdev/operstate" 2>/dev/null || echo down)
if [ "$state" != up ]; then
    down "󰤭" "Off"
    exit 0
fi

# ── Connected: fetch cached SSID from iwd over D-Bus (guarded) ───────
ssid=$(timeout 1 bash -c '
    obj=$(busctl --list tree net.connman.iwd 2>/dev/null \
            | grep -m1 -E "/net/connman/iwd/[0-9]+/[0-9]+$") || exit 0
    net=$(busctl get-property net.connman.iwd "$obj" \
            net.connman.iwd.Station ConnectedNetwork 2>/dev/null \
            | awk "{print \$2}" | tr -d "\"") || exit 0
    [ -z "$net" ] || [ "$net" = "/" ] && exit 0
    busctl get-property net.connman.iwd "$net" \
            net.connman.iwd.Network Name 2>/dev/null | cut -d "\"" -f2
' 2>/dev/null) || ssid=""

[ -z "$ssid" ] && ssid="Wi-Fi"
up "󰤨" "$ssid"
