#!/usr/bin/env bash
# Login screen background. Bazzite desktop uses Plasma Login Manager (greeter wallpaper set in
# /usr/lib/plasmalogin/defaults.conf); the deck variants use SDDM. PNG is the safest format for both.
set -euo pipefail
rsvg-convert -w 1920 -h 1080 -f png -o /usr/share/mountain/wallpaper.png /usr/share/mountain/wallpaper.svg
c=/usr/lib/plasmalogin/defaults.conf
sed -i -E 's|^(Image\|PreviewImage)=.*|\1=file:///usr/share/mountain/wallpaper.png|' "$c"
grep -q '^Image=file:///usr/share/mountain/wallpaper.png$' "$c"
for d in /usr/share/sddm/themes/*/; do
  [[ -f ${d}theme.conf ]] && printf '[General]\ntype=image\nbackground=/usr/share/mountain/wallpaper.png\n' > "${d}theme.conf.user"
done
exit 0
