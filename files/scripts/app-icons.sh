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
# Windows-style folders: places folders (Documents, Pictures...) that We10X lacks in a size become its plain folder, not Breeze's.
for d in $(find /usr/share/icons/We10X-dark -name folder.svg -xtype f -printf '%h
'); do
  for n in documents download music pictures videos desktop; do [[ -e $d/folder-$n.svg ]] || ln -s folder.svg "$d/folder-$n.svg"; done
done
# One icon style: Photos (Gwenview), App Store (Bazaar) and Welcome come from We10X's own set (first match); brand apps keep theirs.
pick() { # new icon name, candidate names...
  local n=$1 c s; shift
  for c; do s=$(find /usr/share/icons/We10X-dark \( -name "$c.svg" -o -name "$c.png" \) -xtype f -print -quit); [[ -n $s ]] && break; done
  [[ -n $s ]] || { echo "app-icons: no We10X icon for $n, keeping the default"; return 0; }
  ln -sf "$s" "${s%/*}/$n.${s##*.}"
}
pick org.kde.gwenview multimedia-photo-manager photos gwenview image-x-generic
pick gwenview multimedia-photo-manager photos image-x-generic
pick io.github.kolunmi.Bazaar org.gnome.Software system-software-install softwarecenter
pick io.github.ublue_os.yafti_gtk help-about system-help
