#!/usr/bin/env bash
# We10X draws a Windows-style logo for start-here/distributor-logo and a 4-square "Windows" grid for applications-all.
# Point those names at the Mountain logo / Breeze's neutral icons, then rebuild the icon caches (Qt trusts them).
set -euo pipefail
logo=/usr/share/icons/hicolor/scalable/apps/mountain-logo.svg
breeze=$(find /usr/share/icons/breeze-dark /usr/share/icons/breeze -name 'applications-all*.svg' -xtype f -print -quit)
[[ -f $logo && -n $breeze ]] || { echo "icons-finalize: logo or breeze icon missing"; exit 1; }
for t in /usr/share/icons/We10X*/; do
  find "$t" \( -name 'start-here*' -o -name 'distributor-logo*' -o -name 'applications-all*' \) -print0 |
    while IFS= read -r -d '' f; do
      case $f in *applications-all*) src=$breeze ;; *) src=$logo ;; esac
      rm -f "$f"; ln -sf "$src" "${f%.*}.svg"
    done
done
# Own identity: other distros' logos (Bazzite/Fedora) become the Mountain logo wherever apps look them up.
find /usr/share/icons/hicolor -name 'bazzite-logo*' -print0 | while IFS= read -r -d '' f; do
  rm -f "$f"; ln -sf "$logo" "${f%.*}.svg"
done
for f in /usr/share/pixmaps/{system-logo-white,fedora-logo,fedora-logo-small,fedora_logo_med,fedora-gdm-logo,fedora_whitelogo_med}.png; do
  [[ -f $f ]] && rsvg-convert -w 256 -h 256 -o "$f" "$logo"
done
for f in /usr/share/pixmaps/{fedora-logo-sprite,fedora_whitelogo}.svg; do [[ -f $f ]] && ln -sf "$logo" "$f"; done
rm -rf /usr/share/wallpapers/bazzite /usr/share/wallpapers/bazzite-*.png
for t in /usr/share/icons/hicolor /usr/share/icons/We10X*; do gtk-update-icon-cache -f -t -q "$t"; done
