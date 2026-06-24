#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
#  Network status (polled) → JSON. DRIVER-SAFE BY DESIGN:
#    • connectivity comes from sysfs operstate (instant, no radio access)
#    • SSID is read from iwd's *cached* D-Bus state — NO scan, and the
#      whole read is wrapped in `timeout 1` as a hard safety net.
#    • never calls iwctl / iw / nmcli, never triggers the slow adapter.
#  Runs async under eww, so even the worst case can't stall Hyprland.
# ─────────────────────────────────────────────────────────────────────
set -uo pipefail

# ── Ethernet first (pure sysfs) ──────────────────────────────────────
for i in /sys/class/net/e*; do
    [ -e "$i" ] || continue
    if [ "$(cat "$i/operstate" 2>/dev/null)" = up ]; then
        jq -cn '{type:"eth",icon:"󰈀",up:true,ssid:"Ethernet",label:"Ethernet"}'
        exit 0
    fi
done

# ── Wi-Fi adapter present? ───────────────────────────────────────────
wdev=""
for i in /sys/class/net/wl*; do [ -e "$i" ] && wdev=$(basename "$i") && break; done
if [ -z "$wdev" ]; then
    jq -cn '{type:"none",icon:"󰤭",up:false,ssid:"",label:"No adapter"}'
    exit 0
fi

state=$(cat "/sys/class/net/$wdev/operstate" 2>/dev/null || echo down)
if [ "$state" != up ]; then
    jq -cn '{type:"wifi",icon:"󰤭",up:false,ssid:"",label:"Disconnected"}'
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
jq -cn --arg ssid "$ssid" '{type:"wifi",icon:"󰤨",up:true,ssid:$ssid,label:$ssid}'
