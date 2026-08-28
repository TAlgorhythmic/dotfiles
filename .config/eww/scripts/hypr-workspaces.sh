#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
#  Hyprland workspaces (deflisten) — emits a JSON array for ids 1..10
#  marking which are occupied and which is active. Event-driven via the
#  Hyprland IPC socket2 (socat); falls back to a single emit if absent.
# ─────────────────────────────────────────────────────────────────────
set -uo pipefail

sig="${HYPRLAND_INSTANCE_SIGNATURE:-}"
sock="${XDG_RUNTIME_DIR}/hypr/${sig}/.socket2.sock"

emit() {
    local active occ
    active=$(hyprctl -j activeworkspace 2>/dev/null | jq '.id' 2>/dev/null) || active=0
    occ=$(hyprctl -j workspaces 2>/dev/null | jq -c '[.[].id]' 2>/dev/null) || occ='[]'
    [ -z "$active" ] && active=0
    [ -z "$occ" ] && occ='[]'
    jq -cn --argjson active "$active" --argjson occ "$occ" \
        '[range(1;11) as $i | {id:$i, occupied:($occ|index($i)!=null), active:($i==$active)}]'
}

emit
[ -S "$sock" ] || exit 0

socat -U - "UNIX-CONNECT:${sock}" 2>/dev/null | while read -r line; do
    case "$line" in
        workspace*|createworkspace*|destroyworkspace*|moveworkspace*|focusedmon*|renameworkspace*)
            emit ;;
    esac
done
