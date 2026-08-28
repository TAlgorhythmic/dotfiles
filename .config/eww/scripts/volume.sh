#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
#  Volume state (deflisten) → JSON. Event-driven via `pactl subscribe`.
# ─────────────────────────────────────────────────────────────────────
set -uo pipefail

emit() {
    local raw vol muted icon
    raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null) || {
        echo '{"vol":0,"muted":true,"icon":"󰖁"}'; return; }
    vol=$(awk '{printf "%d", $2*100}' <<<"$raw")
    if grep -q MUTED <<<"$raw"; then muted=true; else muted=false; fi
    if [ "$muted" = true ] || [ "$vol" -eq 0 ]; then icon="󰖁"
    elif [ "$vol" -lt 34 ]; then icon="󰕿"
    elif [ "$vol" -lt 67 ]; then icon="󰖀"
    else icon="󰕾"; fi
    jq -cn --argjson vol "$vol" --argjson muted "$muted" --arg icon "$icon" \
        '{vol:$vol,muted:$muted,icon:$icon}'
}

emit
pactl subscribe 2>/dev/null | while read -r line; do
    case "$line" in
        *"on sink"*|*"on server"*) emit ;;
    esac
done
