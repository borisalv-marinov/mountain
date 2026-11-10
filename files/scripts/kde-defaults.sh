#!/usr/bin/env bash
# Fedora's kde-settings ships defaults in the kde-profile dir, which KDE reads BEFORE /etc/xdg,
# so drop the keys we set in /etc/xdg from there. Also put the name into the look-and-feel package.
set -euo pipefail
source /usr/share/mountain/config
p=/usr/share/kde-settings/kde-profile/default/xdg
[[ -f $p/plasmarc ]] && sed -i "/^name=/d" "$p/plasmarc"
for f in "$p/kdeglobals" "$p/kwinrc"; do
  [[ -f $f ]] && sed -i -E '/^(LookAndFeelPackage|ColorScheme|AccentColor|widgetStyle|blurEnabled|contrastEnabled|wobblywindowsEnabled)=/d' "$f"
done
sed -i "s|@MOUNTAIN_NAME@|${MOUNTAIN_NAME}|g" /usr/share/plasma/look-and-feel/org.mountain.desktop/metadata.json
