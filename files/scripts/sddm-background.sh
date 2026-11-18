#!/usr/bin/env bash
# Login screen background (blurred wallpaper). Bazzite desktop uses Plasma Login Manager (greeter wallpaper set in
# /usr/lib/plasmalogin/defaults.conf); the deck variants use SDDM. PNG is the safest format for both.
set -euo pipefail
m=/usr/share/mountain
# Login screen: the dark silk wallpaper, softly blurred (like Windows' sign-in screen). Scaled 110 % about the
# centre inside the blur, so the blur never samples past the picture (no light band at the top and bottom edges).
sed -e '0,/<svg[^>]*>/s//&<filter id="mtblur" x="0" y="0" width="1" height="1"><feGaussianBlur stdDeviation="26" edgeMode="duplicate"\/><\/filter><g filter="url(#mtblur)"><g transform="matrix(1.1 0 0 1.1 -192 -108)">/'     -e 's|</svg>|</g></g></svg>|' $m/wallpaper-silk-dark.svg > /tmp/wallpaper-blur.svg
grep -q mtblur /tmp/wallpaper-blur.svg # the blur filter really went in
rsvg-convert -w 2560 -h 1440 -f png -o $m/wallpaper.png /tmp/wallpaper-blur.svg
# Desktop wallpaper packages: Plasma picks the closest size; images_dark is used with a dark colour scheme.
# Mountain Silk (default, our own render; the same light-to-black picture in dark mode, like the owner's desktop),
# Mountain Silk Dark (lock screen) and Mountain Peaks (second choice).
for p in mountain-silk:wallpaper-silk:wallpaper-silk mountain-silk-dark:wallpaper-silk-dark:wallpaper-silk-dark mountain-peaks:wallpaper-light:wallpaper; do
  IFS=: read -r name light dark <<<"$p"
  w=/usr/share/wallpapers/$name/contents
  mkdir -p $w/images $w/images_dark
  for s in 1920x1080 2560x1440 3840x2160; do
    rsvg-convert -w ${s%x*} -h ${s#*x} -f png -o $w/images/$s.png $m/$light.svg
    rsvg-convert -w ${s%x*} -h ${s#*x} -f png -o $w/images_dark/$s.png $m/$dark.svg
  done
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
