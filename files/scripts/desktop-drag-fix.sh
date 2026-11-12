#!/usr/bin/env bash
# Desktop icons vanish when a drag starts before the drag picture is ready (KDE bugs 514333, 515622).
# Backport of KDE's fix (plasma-desktop MR 4141 / 4159, merged into Plasma/6.8, not released yet).
# Skips itself once the installed Plasma already has it; fails loudly if KDE's files changed shape.
set -euo pipefail
ui=/usr/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui
[[ -f $ui/FolderView.qml && -f $ui/FolderItemDelegate.qml ]] || { echo "desktop-drag-fix: desktop QML not found in $ui"; exit 1; }
grep -q dragImageBeingGenerated "$ui/FolderView.qml" && { echo "desktop-drag-fix: already fixed upstream, nothing to do"; exit 0; }
python3 - "$ui" <<'PY'
import re, sys
ui = sys.argv[1]
def patch(name, edits):
    p = f'{ui}/{name}'; s = open(p, encoding='utf-8').read()
    for pat, add in edits:
        s, n = re.subn(pat, lambda m: m.group(0) + add.replace('IND', m.group(1)), s, flags=re.M)
        assert n == 1, f'{name}: expected 1 match for {pat!r}, got {n}'
    open(p, 'w', encoding='utf-8', newline='').write(s)
patch('FolderItemDelegate.qml', [
    (r'^( *)property bool isOnRootView: false\n', 'INDproperty bool dragImageBeingGenerated\n'),
    (r'^( *)if \(selected && !blank\) \{\n(?= *loader\.grabToImage)', 'IND    main.dragImageBeingGenerated = true;\n'),
    (r'^( *)dir\.addItemDragImage\(positioner\.map\(index\).*\n', 'INDdragImageBeingGenerated = false;\n'),
])
patch('FolderView.qml', [
    (r'^( *)if \(pressedItem !== null && dir\.isSelected\(positioner\.map\(pressedItem\.index\)\)\) \{\n(?= *pressedItem\.hideToolTip)',
     'IND    if (pressedItem.dragImageBeingGenerated) {\nIND        return; // drag picture not ready yet: try again on the next pixel\nIND    }\n'),
    (r'^ *gridView\.currentIndex = positioner\.move\(moves\);\n *gridView\.forceLayout\(\);\n( *)\}\n', '\nINDmain.generateDragImage(); // in case the user drags again\n'),
])
print('desktop-drag-fix: applied')
PY
