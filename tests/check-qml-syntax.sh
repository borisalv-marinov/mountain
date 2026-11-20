#!/usr/bin/env bash
# Pre-push check for QML edits: syntax errors only. Uses qmllint (Qt) or the one inside the PySide6 pip package.
# shortcut: KDE modules (Kirigami, Plasma, Kicker) are not installed on a dev PC, so a wrong property on a Plasma
# type is NOT caught here; only the VM run finds that (v7.4: a bad Plasmoid.toolTipMainText broke Start, run 44737821739).
set -uo pipefail
L=$(command -v qmllint qmllint6 2>/dev/null | head -1)
[[ -n $L ]] || L=$(python3 -c "import PySide6,os;print(os.path.join(os.path.dirname(PySide6.__file__),'qmllint.exe' if os.name=='nt' else 'qmllint'))" 2>/dev/null)
[[ -x $L ]] || { echo "no qmllint found (pip install PySide6)"; exit 2; }
bad=0
while read -r f; do
  out=$("$L" "$f" 2>&1 | grep -E "^Error|\[syntax\]| Error:" || true)
  [[ -n $out ]] && { echo "$out"; bad=1; }
done < <(git diff --name-only origin/main -- '*.qml'; git diff --name-only -- '*.qml')
(( bad )) && { echo "QML syntax errors"; exit 1; }
echo "QML syntax ok"
