#!/usr/bin/env bash
# Sets only PRETTY_NAME; ID/NAME stay Bazzite's because its tools read them.
set -euo pipefail
source /usr/share/mountain/config
sed -i "s|^PRETTY_NAME=.*|PRETTY_NAME=\"${MOUNTAIN_NAME} (based on Bazzite)\"|" /usr/lib/os-release
grep -q "^PRETTY_NAME=\"${MOUNTAIN_NAME} " /usr/lib/os-release
# Don't auto-open Bazzite's welcome portal, announcements or Steam at login (less RAM; all stay in the app menu/dock).
rm -f /etc/skel/.config/autostart/bazzite-portal.desktop /etc/skel/.config/autostart/steam.desktop /etc/xdg/autostart/bazzite-announcement.desktop
