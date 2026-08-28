#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
#  Media transport controls. Targets audacious (or first player).
#    play | next | prev | seekpct <0-100>
# ─────────────────────────────────────────────────────────────────────
set -uo pipefail

player=$(playerctl -l 2>/dev/null | grep -m1 audacious || playerctl -l 2>/dev/null | head -n1)
[ -z "${player:-}" ] && exit 0
P=(-p "$player")

case "${1:-}" in
    play) playerctl "${P[@]}" play-pause ;;
    next) playerctl "${P[@]}" next ;;
    prev) playerctl "${P[@]}" previous ;;
    seekpct)
        pct="${2:-0}"
        len_us=$(playerctl "${P[@]}" metadata mpris:length 2>/dev/null || echo 0)
        sec=$(awk -v p="$pct" -v l="$len_us" 'BEGIN{printf "%.2f", (p/100)*(l/1000000)}')
        playerctl "${P[@]}" position "$sec"
        ;;
esac
