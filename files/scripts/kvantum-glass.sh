#!/usr/bin/env bash
# Build MountainGlass from Fedora's KvMojave (dark, macOS-like; kvantum-data package) with glass keys on.
set -euo pipefail
d=/usr/share/Kvantum
cp -r "$d/KvMojave" "$d/MountainGlass"
cd "$d/MountainGlass"
mv KvMojave.kvconfig MountainGlass.kvconfig
mv KvMojave.svg MountainGlass.svg
for kv in translucent_windows=true blurring=true popup_blurring=true reduce_window_opacity=30 reduce_menu_opacity=15; do
  k=${kv%%=*}
  sed -i -E "/^$k=/d" MountainGlass.kvconfig
  sed -i "0,/^\[%General\]/s//[%General]\n$kv/" MountainGlass.kvconfig
done
grep -q '^translucent_windows=true$' MountainGlass.kvconfig
