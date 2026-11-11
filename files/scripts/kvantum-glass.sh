#!/usr/bin/env bash
# Build GlassDark from Fedora's KvMojave (dark, macOS-like; kvantum-data package) with glass keys on.
set -euo pipefail
d=/usr/share/Kvantum
cp -r "$d/KvMojave" "$d/GlassDark"
cd "$d/GlassDark"
mv KvMojave.kvconfig GlassDark.kvconfig
mv KvMojave.svg GlassDark.svg
for kv in translucent_windows=true blurring=true popup_blurring=true reduce_window_opacity=30 reduce_menu_opacity=15; do
  k=${kv%%=*}
  sed -i -E "/^$k=/d" GlassDark.kvconfig
  sed -i "0,/^\[%General\]/s//[%General]\n$kv/" GlassDark.kvconfig
done
grep -q '^translucent_windows=true$' GlassDark.kvconfig
