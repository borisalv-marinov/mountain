#!/usr/bin/env bash
# VS Code's themed icon name is broken in We10X (dock showed "?"); use the icon file the package ships.
set -euo pipefail
P=$(for f in /usr/share/code/resources/app/resources/linux/code.png /usr/share/pixmaps/vscode.png; do [[ -f $f ]] && echo "$f" && break; done)
[[ -n "$P" ]] || { echo "app-icons: VS Code icon file not found"; exit 1; }
# whatever name the launcher uses (vscode, com.visualstudio.code, code...), it gets the file the package ships: the brand icon
# The Start menu (Kirigami.Icon on the kicker model) showed the "unknown" placeholder for an absolute Icon= path and for We10X
# symlink names, so brand icons are installed in hicolor (every Qt/KDE lookup falls back to it) under our own theme names.
install -D -m644 "$P" "/usr/share/icons/hicolor/512x512/apps/mountain-vscode.${P##*.}"
for f in /usr/share/applications/{com.microsoft.VSCode,code}.desktop "/etc/skel/Desktop/Coding/VS Code.desktop"; do [[ -f $f ]] && sed -i "s|^Icon=.*|Icon=mountain-vscode|" "$f"; done
# Notepad (KWrite): Breeze's plain text-editor icon (a pad), not We10X's black/yellow tile that also stood for "unknown"
np=$(find /usr/share/icons/breeze /usr/share/icons/breeze-dark -name 'accessories-text-editor.svg' -xtype f -print -quit)
[[ -n $np ]] || { echo "app-icons: Breeze text editor icon not found"; exit 1; }
install -D -m644 "$np" /usr/share/icons/hicolor/scalable/apps/mountain-notepad.svg
sed -i "s|^Icon=.*|Icon=mountain-notepad|" /usr/share/applications/org.kde.kwrite.desktop
gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
# We10X draws an Outlook-like envelope for "okular" (PDF Reader); point it at Breeze's plain PDF document icon.
pdf=$(find /usr/share/icons/breeze-dark /usr/share/icons/breeze -path '*/mimetypes/64/application-pdf.svg' -print -quit)
[[ -n $pdf ]] || { echo "app-icons: Breeze PDF icon not found"; exit 1; }
find /usr/share/icons/We10X* \( -name 'okular.*' -o -name 'org.kde.okular.*' \) -print0 | while IFS= read -r -d '' f; do rm -f "$f"; ln -sf "$pdf" "${f%.*}.svg"; done
# Windows-style folders: places folders (Documents, Pictures...) that We10X lacks in a size become its plain folder, not Breeze's.
for d in $(find /usr/share/icons/We10X-dark -name folder.svg -xtype f -printf '%h
'); do
  for n in documents download music pictures videos desktop; do [[ -e $d/folder-$n.svg ]] || ln -s folder.svg "$d/folder-$n.svg"; done
done
# One icon style: Photos (Gwenview), App Store (Bazaar) and Welcome come from We10X's own set (first match); brand apps keep theirs.
pick() { # new icon name, candidate names...
  local n=$1 c s; shift
  [[ $n == org.kde.gwenview || $n == gwenview || $n == io.github.* ]] || { find /usr/share/icons/We10X-dark -name "$n.*" -xtype f -print -quit | grep -q . && return 0; } # We10X already has it: keep
  for c; do s=$(find /usr/share/icons/We10X-dark \( -name "$c.svg" -o -name "$c.png" \) -xtype f -print -quit); [[ -n $s ]] && break; done
  [[ -n $s ]] || { echo "app-icons: no We10X icon for $n, keeping the default"; return 0; }
  ln -sf "$s" "${s%/*}/$n.${s##*.}"
}
pick org.kde.gwenview multimedia-photo-manager photos gwenview image-x-generic
pick gwenview multimedia-photo-manager photos image-x-generic
pick io.github.kolunmi.Bazaar org.gnome.Software system-software-install softwarecenter
pick io.github.ublue_os.yafti_gtk help-about system-help
# System apps from the one We10X set, whatever the launcher asks for (Breeze and Papirus names fall back to We10X's own)
pick accessories-calculator calculator accessories-calculator
pick utilities-terminal terminal utilities-terminal
pick system-file-manager folder-open system-file-manager
pick preferences-system settings preferences-system
pick security-high security-high security-medium
pick accessories-text-editor text-editor accessories-text-editor
pick kwrite accessories-text-editor text-editor
pick org.kde.kwrite accessories-text-editor text-editor
pick utilities-system-monitor utilities-system-monitor task-manager
pick org.kde.spectacle accessories-screenshot applets-screenshooter
