#!/usr/bin/env bash
# Windows-familiar app names, and developer/advanced entries hidden from the start menu (still runnable from Terminal).
set -euo pipefail
a=/usr/share/applications
ren() { # file new-name; translated Name[xx] lines are dropped so every language shows the familiar name
  [[ -f $a/$1 ]] || { echo "windows-names: missing $1"; return 1; }
  sed -i -E "0,/^Name=/s|^Name=.*|Name=$2|; /^Name\[/d" "$a/$1"
}
ren systemsettings.desktop "All Settings" # the full KDE app; "Settings" is our Windows-style one (org.mountain.settings)
ren org.kde.dolphin.desktop "File Explorer"
ren org.kde.konsole.desktop "Terminal"
ren org.kde.plasma-systemmonitor.desktop "Task Manager"
ren org.kde.kinfocenter.desktop "System Information"
ren org.kde.kwrite.desktop "Notepad"
# v6: everyday apps with their Windows names
ren org.kde.kcalc.desktop "Calculator"
ren org.kde.gwenview.desktop "Photos"
ren org.kde.haruna.desktop "Media Player"
ren org.kde.kamoso.desktop "Camera"
ren org.kde.kclock.desktop "Clock"
ren org.kde.spectacle.desktop "Snipping Tool"
ren org.kde.kolourpaint.desktop "Paint"
ren org.kde.krecorder.desktop "Sound Recorder"
ren org.kde.skanlite.desktop "Scanner"
ren org.kde.kdeconnect.app.desktop "Phone Link"
ren com.microsoft.VSCode.desktop "VS Code"
# Own identity: no other distro's name on everyday apps
ren io.github.kolunmi.Bazaar.desktop "App Store"
ren io.github.ublue_os.yafti_gtk.desktop "Welcome"
ren io.github.rfrench3.bazzite-updater.desktop "Updates"
pl=$a/org.kde.kdeconnect.app.desktop
[[ -f $pl ]] && sed -i 's|^Exec=.*|Exec=/usr/libexec/mountain-phonelink|' "$pl"
for f in io.github.kolunmi.Bazaar io.github.ublue_os.yafti_gtk io.github.rfrench3.bazzite-updater; do # descriptions and actions too
  sed -i -E '/^(Comment|GenericName|Name|Keywords)(\[|=)/{s/Bazzite Portal/Welcome/g; s/Bazzite/your PC/g}' "$a/$f.desktop"
done
for f in kvantummanager org.kde.kwalletmanager kwalletmanager5-kwalletd org.kde.khelpcenter input-remapper-gtk \
         org.kde.kdebugsettings org.kde.kjournaldbrowser org.kde.kcolorschemeeditor org.kde.keditbookmarks \
         org.kde.knetattach yad-icon-browser bbrew bazzite-documentation discourse gkbd-keyboard-display org.freedesktop.IBus.Setup \
         com.gerbilsoft.rom-properties.rp-config org.kde.kdeconnect.sms org.kde.kdeconnect.nonplasma org.kde.plasma-interactiveconsole ibus-setup-anthy ibus-setup-chewing \
         ibus-setup-hangul ibus-setup-libbopomofo ibus-setup-libpinyin ibus-setup-m17n ibus-setup-tb ibus-setup-typing-booster; do
  [[ -f $a/$f.desktop ]] || continue
  sed -i '/^NoDisplay=/d' "$a/$f.desktop"
  sed -i '0,/^\[Desktop Entry\]/s//[Desktop Entry]\nNoDisplay=true/' "$a/$f.desktop"
done

# Our file-type defaults must beat Fedora's profile-dir lists (read before /etc/xdg); later keys in a merged group win.
for f in /usr/share/kde-settings/kde-profile/default/xdg/{kde-,}mimeapps.list; do
  [[ -f $f ]] && { echo; cat /etc/xdg/mimeapps.list; } >> "$f"
done
exit 0
