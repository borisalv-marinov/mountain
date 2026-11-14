#!/usr/bin/env bash
# Desktop icon labels readable on the light half of Mountain Silk (white on #F0F0F0 is 1.1:1 without a shadow).
# Plasma draws them with org.kde.plasma.extras ShadowedLabel (radius 4, spread 0.35); make the shadow Windows-strength
# (a soft dark plate behind each line, about 11:1 at the glyph edge). Same qmldir "prefer" trick as lock-screen.sh.
# Fails loudly if KDE's file changes shape.
set -euo pipefail
d=$(find /usr/lib64/qt6/qml /usr/lib/qt6/qml -type d -path '*/org/kde/plasma/extras' -print -quit 2>/dev/null || true)
[[ -n $d && -f $d/qmldir && -f $d/ShadowedLabel.qml ]] || { echo "desktop-labels: ShadowedLabel.qml not found on disk"; exit 1; }
sed -i '/^prefer /d' "$d/qmldir"
python3 - "$d/ShadowedLabel.qml" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = '        radius: 4.0\n        samples: radius * 2 + 1\n        spread: 0.35\n'
new = '        radius: 6.0 // Mountain: stronger shadow for light wallpapers\n        samples: radius * 2 + 1\n        spread: 0.55\n'
assert s.count(old) == 1, f'ShadowedLabel.qml: expected 1 shadow block, got {s.count(old)}'
open(p, 'w', encoding='utf-8', newline='').write(s.replace(old, new))
PY
grep -q 'spread: 0.55' "$d/ShadowedLabel.qml"
! grep -q '^prefer ' "$d/qmldir"
echo "desktop-labels: shadow patched in $d"
