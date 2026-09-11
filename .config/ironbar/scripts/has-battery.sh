#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
#  Battery present? → exit code for the battery module's `show_if`.
#  0 = show (laptop), 1 = hide (desktop). Pure sysfs, no UPower call.
#    • type must be Battery — skips AC adapters and USB-C ports
#    • scope=Device is a peripheral (wireless mouse, gamepad), not ours
#    • present=0 is an empty bay, which UPower would report as 0%
# ─────────────────────────────────────────────────────────────────────
for ps in /sys/class/power_supply/*; do
    [ "$(cat "$ps/type" 2>/dev/null)" = Battery ] || continue
    [ "$(cat "$ps/scope" 2>/dev/null)" = Device ] && continue
    [ "$(cat "$ps/present" 2>/dev/null || echo 1)" = 1 ] || continue
    exit 0
done
exit 1
