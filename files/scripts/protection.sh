#!/usr/bin/env bash
# v5.1: Task Manager on Ctrl+Shift+Esc (Ctrl+Esc kept), on-demand ClamAV with no background downloads, crisp fonts.
set -euo pipefail
# Windows shortcuts on the apps themselves: Ctrl+Shift+Esc Task Manager, Win+I Settings, Win+R Run, Win+E File Explorer
sc() { # desktop-file shortcuts, in applications/ and in kglobalaccel/ (Plasma 6 reads that copy first when it exists)
  local f n=0
  for f in /usr/share/applications/$1 /usr/share/kglobalaccel/$1; do
    [[ -e $f ]] || continue
    sed -i '/^X-KDE-Shortcuts=/d' "$f"; sed -i "0,/^\[Desktop Entry\]/s//[Desktop Entry]\nX-KDE-Shortcuts=$2/" "$f"; n=$((n + 1))
  done
  [[ $n -gt 0 ]] || { echo "protection: missing $1"; return 1; }
}
sc org.kde.plasma-systemmonitor.desktop "Ctrl+Shift+Esc,Ctrl+Esc"
sc org.mountain.settings.desktop Meta+I
sc org.kde.krunner.desktop "Alt+Space,Alt+F2,Search" # Win+R is the Run dialog (org.mountain.run.desktop)
sc org.kde.dolphin.desktop Meta+E
# PrtSc: a full screenshot, saved to Pictures/Screenshots (Spectacle's own launch would reopen its last-used mode, e.g. a region)
n=0
for f in /usr/share/applications/org.kde.spectacle.desktop /usr/share/kglobalaccel/org.kde.spectacle.desktop; do
  [[ -e $f ]] || continue
  # and Spectacle's own Win+R (record a region) and Win+Shift+S would take the Run dialog's and the snip's keys
  awk '/^\[/ { s = $0 } /^X-KDE-Shortcuts=/ { if (s == "[Desktop Entry]") $0 = "X-KDE-Shortcuts="; else if (s == "[Desktop Action FullScreenScreenShot]") $0 = "X-KDE-Shortcuts=Print"; else if (s == "[Desktop Action RecordRegion]") $0 = "X-KDE-Shortcuts=Meta+Shift+R" } { print }' "$f" > "$f.new"
  mv "$f.new" "$f"; grep -q '^X-KDE-Shortcuts=Print$' "$f"; n=$((n + 1))
  if grep -qE '^X-KDE-Shortcuts=(.*,)?Meta\+(R|Shift\+S)(,|$)' "$f"; then echo "protection: Spectacle keeps Win+R or Win+Shift+S in $f"; exit 1; fi
done
[[ $n -gt 0 ]]
# Win+G: MangoHud performance overlay in games (hidden until toggled)
install -d /etc/xdg/MangoHud
printf '# Win+G shows or hides the overlay (like the Xbox Game Bar)\nno_display\ntoggle_hud=Super_L+g\nfps\nframe_timing\ncpu_stats\ngpu_stats\nram\nvram\n' > /etc/xdg/MangoHud/MangoHud.conf
# ClamAV: definitions only through mountain-virus-definitions.service (Scan now); no daemon, timer or cron job
sed -i -E 's/^Example/#Example/' /etc/freshclam.conf
rm -f /etc/cron.d/clamav-update /etc/cron.d/clamav-freshclam
systemctl disable clamav-freshclam.service clamav-freshclam-once.timer 2>/dev/null || true
command -v clamscan freshclam >/dev/null
# sign-in brute force: faillock locks the account for 5 minutes after 5 wrong passwords
authselect current >/dev/null # no profile = no lockout: fail the build, not ship it silently
authselect enable-feature with-faillock >/dev/null
printf '\n# Mountain: lock for 5 minutes after 5 wrong passwords\ndeny = 5\nunlock_time = 300\n' >> /etc/security/faillock.conf
# fonts outside KDE (GTK, Electron, Flatpak) render like KDE apps: RGB subpixel, slight hinting (Fedora's default)
c=/usr/share/fontconfig/conf.avail/10-sub-pixel-rgb.conf
[[ -e $c ]] && ln -sf "$c" /etc/fonts/conf.d/10-sub-pixel-rgb.conf
exit 0
