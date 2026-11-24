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


# Version shown to users (Settings > About reads MOUNTAIN_VERSION): ID/VERSION_ID stay Bazzite's/Fedora's for the tools that parse them.
sed -i '/^MOUNTAIN_\(VERSION\|BUILD\)=/d' "$o"
printf 'MOUNTAIN_VERSION="%s"\nMOUNTAIN_BUILD="%s"\n' "${MOUNTAIN_VERSION:-7.6}" "$(date -u +%Y%m%d)" >> "$o"
grep -q '^MOUNTAIN_BUILD="[0-9]\{8\}"' "$o"
# Info Center: show Mountain's version, not Fedora's VERSION_ID ("Mountain 45")
printf 'UseOSReleaseVersion=false\nVersion=%s\n' "${MOUNTAIN_VERSION:-7.6}" >> /usr/share/kde-settings/kde-profile/default/xdg/kcm-about-distrorc
# The first-run portal is Bazzite's (its text says Bazzite, links to Bazzite docs/Discord/Reddit): never listed in Start.
# KDE Desktop Sharing (krfb): its remote-control prompt pre-ticks "allow without asking next time"; hidden here even if the recipe keeps it.
for f in /usr/share/applications/io.github.ublue_os.yafti_gtk.desktop /usr/share/applications/org.kde.krfb*.desktop; do
  [[ -f $f ]] || continue
  sed -i '/^NoDisplay=/d; 0,/^\[Desktop Entry\]/s//[Desktop Entry]\nNoDisplay=true/' "$f"
done
# Clock tooltip showed "UTC+00:00:01" when the system zone is unset: make UTC explicit so Qt names it "UTC".
[[ -e /etc/localtime ]] || ln -s ../usr/share/zoneinfo/UTC /etc/localtime
