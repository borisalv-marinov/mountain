#!/usr/bin/env bash
# Static checks for the v7.6 branding fixes (no image needed). Run from the repo root.
set -u
f=0; ok() { echo "PASS $1"; }; bad() { echo "FAIL $1"; f=1; }
chk() { grep -qE "$2" "$3" && ok "$1" || bad "$1"; }
chk "os-release gets MOUNTAIN_VERSION" 'MOUNTAIN_VERSION=' files/scripts/branding.sh
chk "yafti (Bazzite Portal) hidden from Start" 'io\.github\.ublue_os\.yafti_gtk\.desktop' files/scripts/branding.sh
chk "krfb hidden from Start" 'org\.kde\.krfb' files/scripts/branding.sh
chk "KWrite hides input mode" '^Show Statusbar Input Mode=false$' files/system/etc/xdg/kwriterc
chk "KWrite hides dictionary" '^Show Statusbar Dictionary=false$' files/system/etc/xdg/kwriterc
chk "KWrite hides indentation" '^Show Statusbar Tab Settings=false$' files/system/etc/xdg/kwriterc
chk "KWrite hides syntax mode" '^Show Statusbar Highlighting Mode=false$' files/system/etc/xdg/kwriterc
chk "KWrite shows line ending" '^Show Line Ending Type in Statusbar=true$' files/system/etc/xdg/kwriterc
chk "clock: /etc/localtime made explicit" 'ln -s \.\./usr/share/zoneinfo/UTC /etc/localtime' files/scripts/branding.sh
g=files/system/usr/lib/greenboot/check/required.d/20-mountain-greeter.sh
[[ -x $g ]] && ok "greeter check executable" || bad "greeter check executable"
chk "greeter check waits for display-manager and greeter" 'display-manager.service' "$g"
bash -n "$g" && bash -n files/scripts/branding.sh && bash -n tests/vm/closeall.sh && ok "scripts parse" || bad "scripts parse"
exit $f
