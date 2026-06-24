#!/usr/bin/env bash
# Volume actions for the bar (scroll + click-to-mute).
case "${1:-}" in
    up)   wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+ ;;
    down) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
    mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
esac
