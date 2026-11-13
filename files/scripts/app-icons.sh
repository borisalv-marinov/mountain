#!/usr/bin/env bash
# VS Code's themed icon name is broken in We10X (dock showed "?"); use the icon file the package ships.
set -euo pipefail
P=$(ls /usr/share/pixmaps/vscode.png /usr/share/code/resources/app/resources/linux/code.png 2>/dev/null | head -1)
[[ -n "$P" ]] || { echo "app-icons: VS Code icon file not found"; exit 1; }
grep -rlxZ 'Icon=vscode' /usr/share/applications /etc/skel/Desktop | xargs -0r sed -i "s|^Icon=vscode\$|Icon=$P|"
# We10X draws an Outlook-like envelope for "okular" (PDF Reader); point it at Breeze's plain PDF document icon.
pdf=$(find /usr/share/icons/breeze-dark /usr/share/icons/breeze -path '*/mimetypes/64/application-pdf.svg' -print -quit)
[[ -n $pdf ]] || { echo "app-icons: Breeze PDF icon not found"; exit 1; }
find /usr/share/icons/We10X* \( -name 'okular.*' -o -name 'org.kde.okular.*' \) -print0 | while IFS= read -r -d '' f; do rm -f "$f"; ln -sf "$pdf" "${f%.*}.svg"; done
