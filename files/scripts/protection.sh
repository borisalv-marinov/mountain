#!/usr/bin/env bash
# v5.1: Task Manager on Ctrl+Shift+Esc (Ctrl+Esc kept), on-demand ClamAV with no background downloads, crisp fonts.
set -euo pipefail
a=/usr/share/applications/org.kde.plasma-systemmonitor.desktop
sed -i '/^X-KDE-Shortcuts=/d' "$a"
sed -i '0,/^\[Desktop Entry\]/s//[Desktop Entry]\nX-KDE-Shortcuts=Ctrl+Shift+Esc,Ctrl+Esc/' "$a"
grep -q '^X-KDE-Shortcuts=Ctrl+Shift+Esc,Ctrl+Esc$' "$a"
# more Windows shortcuts on the apps themselves: Win+I Settings, Win+R Run, Win+E File Explorer
sc() { # desktop-file shortcuts
  local f=/usr/share/applications/$1; [[ -f $f ]] || { echo "protection: missing $1"; return 1; }
  sed -i '/^X-KDE-Shortcuts=/d' "$f"; sed -i "0,/^\[Desktop Entry\]/s//[Desktop Entry]\nX-KDE-Shortcuts=$2/" "$f"
}
sc org.mountain.settings.desktop Meta+I
sc org.kde.krunner.desktop "Meta+R,Alt+Space,Alt+F2,Search"
sc org.kde.dolphin.desktop Meta+E
# Win+G: MangoHud performance overlay in games (hidden until toggled)
install -d /etc/xdg/MangoHud
printf '# Mountain: Win+G shows or hides the overlay (like the Xbox Game Bar)\nno_display\ntoggle_hud=Super_L+g\nfps\nframe_timing\ncpu_stats\ngpu_stats\nram\nvram\n' > /etc/xdg/MangoHud/MangoHud.conf
# ClamAV: definitions only through mountain-virus-definitions.service (Scan now); no daemon, timer or cron job
sed -i -E 's/^Example/#Example/' /etc/freshclam.conf
rm -f /etc/cron.d/clamav-update /etc/cron.d/clamav-freshclam
systemctl disable clamav-freshclam.service clamav-freshclam-once.timer 2>/dev/null || true
command -v clamscan freshclam >/dev/null
# fonts outside KDE (GTK, Electron, Flatpak) render like KDE apps: RGB subpixel, slight hinting (Fedora's default)
c=/usr/share/fontconfig/conf.avail/10-sub-pixel-rgb.conf
[[ -e $c ]] && ln -sf "$c" /etc/fonts/conf.d/10-sub-pixel-rgb.conf
exit 0
