#!/usr/bin/env bash
# Apply a mouse acceleration profile and remember the choice.
# Usage: set-accel.sh <adaptive|custom>
set -euo pipefail

profile="${1:-}"
state="$HOME/.cache/accel_profile"

case "$profile" in
    adaptive)
        # Profile defined in ~/.config/hypr/hyprland.lua (Hyprland-native libinput).
        # The Lua parser rejects `hyprctl keyword`, so apply it at runtime via eval.
        hyprctl eval 'hl.config({ input = { accel_profile = "adaptive", sensitivity = -0.2 } })'
        ;;
    custom)
        # Custom motion curve, ported from ~/accel.sh to Hyprland's native
        # libinput custom profile so it works under Wayland (not just XWayland).
        #   accel.sh: Motion Step 1.9 / Points 0.0 1.1 2.6 5.4 7.0 8.5 11.0
        #   hyprland: accel_profile = custom <step> <point...>
        # sensitivity is neutralised so the curve is applied as-is.
        hyprctl eval 'hl.config({ input = { accel_profile = "custom 1.9 0.0 1.1 2.6 5.4 7.0 8.5 11.0", sensitivity = 0 } })'
        ;;
    *)
        echo "set-accel.sh: unknown profile '$profile' (expected: adaptive|custom)" >&2
        exit 1
        ;;
esac

echo "$profile" > "$state"
