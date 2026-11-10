#!/usr/bin/env bash
# SDDM image backgrounds are safest as PNG, so convert our SVG, then point every installed SDDM theme at it.
set -euo pipefail
rsvg-convert -w 1920 -h 1080 -f png -o /usr/share/mountain/wallpaper.png /usr/share/mountain/wallpaper.svg
for d in /usr/share/sddm/themes/*/; do
  [[ -f ${d}theme.conf ]] && printf '[General]\ntype=image\nbackground=/usr/share/mountain/wallpaper.png\n' > "${d}theme.conf.user"
done
ls /usr/share/sddm/themes; grep -rq wallpaper.png /usr/share/sddm/themes --include=theme.conf.user
