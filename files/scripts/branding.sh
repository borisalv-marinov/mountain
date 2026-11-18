#!/usr/bin/env bash
# Sets PRETTY_NAME, LOGO and the boot-menu name; ID/NAME stay Bazzite's because its tools read them.
set -euo pipefail
source /usr/share/mountain/config
o=/usr/lib/os-release
sed -i -e "s|^PRETTY_NAME=.*|PRETTY_NAME=\"${MOUNTAIN_NAME} (based on Bazzite)\"|" \
       -e "s|^LOGO=.*|LOGO=mountain-logo|" \
       -e "s|^BOOTLOADER_NAME=\"Bazzite |BOOTLOADER_NAME=\"${MOUNTAIN_NAME} |" "$o"
grep -q '^LOGO=' "$o" || echo 'LOGO=mountain-logo' >> "$o"
grep -q "^PRETTY_NAME=\"${MOUNTAIN_NAME} " "$o"
# Don't auto-open Bazzite's welcome portal, announcements or Steam at login (less RAM; all stay in the app menu/dock).
rm -f /etc/skel/.config/autostart/bazzite-portal.desktop /etc/skel/.config/autostart/steam.desktop /etc/xdg/autostart/bazzite-announcement.desktop
# KDE Connect (phone link, ~80 MB) was D-Bus activated by the tray even with its autostart hidden.
rm -f /usr/share/dbus-1/services/org.kde.kdeconnect.service

# About page (Settings > About): the kde-profile dir is read before /etc/xdg, and phase 10 keeps the name out of /etc/xdg.
logo=/usr/share/icons/hicolor/scalable/apps/mountain-logo.svg
rm -f /etc/xdg/kcm-about-distrorc
mkdir -p /usr/share/kde-settings/kde-profile/default/xdg
printf '[General]\nLogoPath=%s\nName=%s\nWebsite=https://github.com/borisalv-marinov/mountain\nVariant=\n' "$logo" "$MOUNTAIN_NAME" \
  > /usr/share/kde-settings/kde-profile/default/xdg/kcm-about-distrorc

