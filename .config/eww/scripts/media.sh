#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
#  Now-playing state (polled) → JSON for the bar + media popup.
#  Prefers audacious, falls back to the first available player.
#  Album art: uses mpris:artUrl when present, otherwise extracts the
#  embedded cover with ffmpeg (cached by file path).
# ─────────────────────────────────────────────────────────────────────
set -uo pipefail

cache="${XDG_CACHE_HOME:-$HOME/.cache}/eww-art"
mkdir -p "$cache"

none='{"present":false,"status":"Stopped","title":"Nothing playing","artist":"","album":"","len":0,"pos":0,"frac":0,"pos_str":"0:00","len_str":"0:00","art":""}'

player=$(playerctl -l 2>/dev/null | grep -m1 audacious || playerctl -l 2>/dev/null | head -n1)
[ -z "${player:-}" ] && { echo "$none"; exit 0; }

P=(-p "$player")
status=$(playerctl "${P[@]}" status 2>/dev/null || echo Stopped)
title=$(playerctl "${P[@]}" metadata xesam:title 2>/dev/null || echo "")
artist=$(playerctl "${P[@]}" metadata xesam:artist 2>/dev/null || echo "")
album=$(playerctl "${P[@]}" metadata xesam:album 2>/dev/null || echo "")
len_us=$(playerctl "${P[@]}" metadata mpris:length 2>/dev/null || echo 0)
pos=$(playerctl "${P[@]}" position 2>/dev/null || echo 0)
url=$(playerctl "${P[@]}" metadata xesam:url 2>/dev/null || echo "")
art=$(playerctl "${P[@]}" metadata mpris:artUrl 2>/dev/null || echo "")

[ -z "$title" ] && title="Unknown"
[[ "$len_us" =~ ^[0-9]+$ ]] || len_us=0
[[ "$pos"    =~ ^[0-9.]+$ ]] || pos=0

len=$(awk -v u="$len_us" 'BEGIN{printf "%d", u/1000000}')
posI=$(awk -v p="$pos" 'BEGIN{printf "%d", p}')
frac=0
[ "$len" -gt 0 ] && frac=$(awk -v p="$pos" -v l="$len" 'BEGIN{f=p/l; if(f<0)f=0; if(f>1)f=1; printf "%.4f", f}')

fmt() { printf '%d:%02d' $(( $1/60 )) $(( $1%60 )); }
pos_str=$(fmt "$posI"); len_str=$(fmt "$len")

# ── album art ────────────────────────────────────────────────────────
artpath=""
case "$art" in
    file://*) artpath="${art#file://}" ;;
esac
if [ -z "$artpath" ] && [ -n "$url" ]; then
    case "$url" in
        file://*)
            f="${url#file://}"
            f=$(printf '%b' "${f//%/\\x}")            # url-decode %20 etc.
            key=$(printf '%s' "$f" | md5sum | cut -d' ' -f1)
            out="$cache/$key.jpg"
            if [ ! -f "$out" ] && [ -f "$f" ]; then
                ffmpeg -nostdin -loglevel quiet -y -i "$f" -an -an -c:v mjpeg -frames:v 1 "$out" \
                    </dev/null >/dev/null 2>&1 || rm -f "$out"
            fi
            [ -f "$out" ] && artpath="$out"
            ;;
    esac
fi

jq -cn \
    --arg status "$status" --arg title "$title" --arg artist "$artist" --arg album "$album" \
    --arg art "$artpath" --arg pos_str "$pos_str" --arg len_str "$len_str" \
    --argjson len "$len" --argjson pos "$posI" --argjson frac "$frac" \
    '{present:true,status:$status,title:$title,artist:$artist,album:$album,
      len:$len,pos:$pos,frac:$frac,pos_str:$pos_str,len_str:$len_str,art:$art}'
