#!/usr/bin/env bash
# "Hello, <name>" above the password box on the login screen (Plasma Login Manager) and the lock screen.
# Both build their sign-in from KDE's shared QML module org.kde.breeze.components. Its qmldir "prefer"s the copy
# compiled into the plugin, so drop that line to make Qt load the files on disk, then patch UserDelegate.qml.
# Fails loudly if KDE's files change shape. The lock screen has kscreenlocker's built-in fallback if QML breaks.
set -euo pipefail
d=$(find /usr/lib64/qt6/qml /usr/lib/qt6/qml -type d -path '*/org/kde/breeze/components' -print -quit 2>/dev/null || true)
[[ -n $d && -f $d/qmldir && -f $d/UserDelegate.qml ]] || { echo "lock-screen: breeze components not found"; exit 1; }
sed -i '/^prefer /d' "$d/qmldir"
python3 - "$d/UserDelegate.qml" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = '        text: wrapper.name\n'
new = '        text: wrapper.isCurrent && wrapper.name ? "Hello, " + wrapper.name : wrapper.name // Mountain: Windows-style greeting\n'
assert s.count(old) == 1, f'UserDelegate.qml: expected 1 "text: wrapper.name", got {s.count(old)}'
open(p, 'w', encoding='utf-8', newline='').write(s.replace(old, new))
PY
grep -q '"Hello, "' "$d/UserDelegate.qml"
! grep -q '^prefer ' "$d/qmldir"
echo "lock-screen: greeting patched in $d"
