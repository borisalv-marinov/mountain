#!/usr/bin/env bash
# v5.1: Task Manager on Ctrl+Shift+Esc (Ctrl+Esc kept), on-demand ClamAV with no background downloads, crisp fonts.
set -euo pipefail
a=/usr/share/applications/org.kde.plasma-systemmonitor.desktop
sed -i '/^X-KDE-Shortcuts=/d' "$a"
sed -i '0,/^\[Desktop Entry\]/s//[Desktop Entry]\nX-KDE-Shortcuts=Ctrl+Shift+Esc,Ctrl+Esc/' "$a"
grep -q '^X-KDE-Shortcuts=Ctrl+Shift+Esc,Ctrl+Esc$' "$a"
# ClamAV: definitions only through mountain-virus-definitions.service (Scan now); no daemon, timer or cron job
sed -i -E 's/^Example/#Example/' /etc/freshclam.conf
rm -f /etc/cron.d/clamav-update /etc/cron.d/clamav-freshclam
systemctl disable clamav-freshclam.service clamav-freshclam-once.timer 2>/dev/null || true
command -v clamscan freshclam >/dev/null
# fonts outside KDE (GTK, Electron, Flatpak) render like KDE apps: RGB subpixel, slight hinting (Fedora's default)
c=/usr/share/fontconfig/conf.avail/10-sub-pixel-rgb.conf
[[ -e $c ]] && ln -sf "$c" /etc/fonts/conf.d/10-sub-pixel-rgb.conf
exit 0
