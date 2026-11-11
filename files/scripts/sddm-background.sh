#!/usr/bin/env bash
# Login screen background. Bazzite desktop uses Plasma Login Manager (greeter wallpaper set in
# /usr/lib/plasmalogin/defaults.conf); the deck variants use SDDM. PNG is the safest format for both.
set -euo pipefail
m=/usr/share/mountain
rsvg-convert -w 3840 -h 2160 -f png -o $m/wallpaper.png $m/wallpaper.svg
# Desktop wallpaper package: Plasma picks the closest size; images_dark is used with a dark colour scheme.
w=/usr/share/wallpapers/mountain-peaks/contents
mkdir -p $w/images $w/images_dark
for s in 1920x1080 2560x1440 3840x2160; do
  rsvg-convert -w ${s%x*} -h ${s#*x} -f png -o $w/images/$s.png $m/wallpaper-light.svg
  rsvg-convert -w ${s%x*} -h ${s#*x} -f png -o $w/images_dark/$s.png $m/wallpaper.svg
done
c=/usr/lib/plasmalogin/defaults.conf
sed -i -E 's|^(Image\|PreviewImage)=.*|\1=file:///usr/share/mountain/wallpaper.png|' "$c"
grep -q '^Image=file:///usr/share/mountain/wallpaper.png$' "$c"
for d in /usr/share/sddm/themes/*/; do
  [[ -f ${d}theme.conf ]] && printf '[General]\ntype=image\nbackground=/usr/share/mountain/wallpaper.png\n' > "${d}theme.conf.user"
done
# Boot splash: bgrt shows the spinner theme's watermark under the firmware logo (initramfs is rebuilt later in the recipe).
rsvg-convert -w 96 -h 96 -o /usr/share/mountain/watermark.png /usr/share/icons/hicolor/scalable/apps/mountain-logo.svg
cp /usr/share/mountain/watermark.png /usr/share/plymouth/themes/spinner/watermark.png
exit 0
