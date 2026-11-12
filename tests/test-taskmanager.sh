#!/usr/bin/env bash
# Tests mountain-taskmanager's Startup apps list and switch (the parts that change files).
S=$(dirname "$0")/../files/system/usr/libexec/mountain-taskmanager
T=$(mktemp -d); rc=0
ok() { if eval "$1"; then echo "ok: $2"; else echo "FAIL: $2"; rc=1; fi; }
mkdir -p "$T/sys" "$T/home/.config/autostart"
printf '[Desktop Entry]\nName=Chat\nExec=chat --tray\n' > "$T/sys/chat.desktop"
printf '[Desktop Entry]\nName=Shell\nExec=plasmashell\n' > "$T/sys/org.kde.plasmashell.desktop"
printf '[Desktop Entry]\nName=Wallet\nExec=pam_kwallet_init\n' > "$T/sys/pam_kwallet_init.desktop"
printf '[Desktop Entry]\nHidden=true\n' > "$T/sys/vendor-off.desktop"
printf '[Desktop Entry]\nName=Gnome only\nOnlyShowIn=GNOME;\n' > "$T/sys/gnome.desktop"
printf '[Desktop Entry]\nName=Steam\nExec=steam -silent\n' > "$T/home/.config/autostart/steam.desktop"
run() { HOME=$T/home XDG_CONFIG_HOME= MOUNTAIN_AUTOSTART_SYSTEM=$T/sys bash "$S" "$@"; }
L=$(run startup)
ok '[[ $(head -1 <<<"$L") == $'"'"'id\tName\tStatus\tCommand'"'"' ]]' "header"
ok 'grep -q $'"'"'^chat.desktop\tChat\tEnabled\tchat --tray$'"'"' <<<"$L"' "system app listed, enabled"
ok 'grep -q $'"'"'^steam.desktop\tSteam\tEnabled'"'"' <<<"$L"' "user app listed"
ok '! grep -q -e plasmashell -e pam_kwallet <<<"$L"' "desktop core hidden (also names at a line end)"
ok '! grep -q -e vendor-off -e gnome <<<"$L"' "system-disabled and GNOME-only entries hidden"
run startup-set chat.desktop off
ok 'grep -qx "Hidden=true" "$T/home/.config/autostart/chat.desktop"' "off writes a Hidden=true override"
ok 'run startup | grep -q $'"'"'^chat.desktop\tChat\tDisabled'"'"'' "shows Disabled"
run startup-set chat.desktop on
ok '[[ ! -e $T/home/.config/autostart/chat.desktop ]]' "on removes our override"
run startup-set steam.desktop off
ok 'grep -qx "Hidden=true" "$T/home/.config/autostart/steam.desktop" && grep -qx "Exec=steam -silent" "$T/home/.config/autostart/steam.desktop"' "user entry hidden in place"
run startup-set steam.desktop on
ok '! grep -q Hidden "$T/home/.config/autostart/steam.desktop"' "user entry back on"
ok '! run startup-set "../evil.desktop" off 2>/dev/null' "rejects paths"
ok '! run service stop "foo; rm -rf ~" 2>/dev/null' "rejects bad unit names"
ok '[[ $(run device | head -1) == $'"'"'id\tPart\tModel'"'"' ]]' "device header"
rm -rf "$T"; exit $rc
