#!/usr/bin/env bash
# VS Code's themed icon name is broken in We10X (dock showed "?"); use the icon file the package ships.
set -euo pipefail
P=$(ls /usr/share/pixmaps/vscode.png /usr/share/code/resources/app/resources/linux/code.png 2>/dev/null | head -1)
[[ -n "$P" ]] || { echo "app-icons: VS Code icon file not found"; exit 1; }
sed -i "s|^Icon=vscode\$|Icon=$P|" /usr/share/applications/code.desktop /etc/skel/Desktop/Coding/code.desktop
