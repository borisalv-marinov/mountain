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
# Startup apps as Windows shows them: Mountain/desktop internals hidden, friendly names, no command paths
printf '[Desktop Entry]\nName=Lite Mode\nExec=/usr/libexec/mountain-lite-mode\n' > "$T/sys/mountain-lite-mode.desktop"
printf '[Desktop Entry]\nName=Baloo File Daemon\nExec=baloo_file\n' > "$T/sys/baloo_file.desktop"
printf '[Desktop Entry]\nName=Helper\nExec=/usr/libexec/some-helper --x\n' > "$T/sys/helper.desktop"
printf '[Desktop Entry]\nName=KDE Connect\nExec=kdeconnectd\n' > "$T/sys/org.kde.kdeconnect.daemon.desktop"
runs() { HOME=$T/home XDG_CONFIG_HOME= MOUNTAIN_AUTOSTART_SYSTEM=$T/sys bash "$S-startup"; }
L=$(runs)
ok '[[ $(head -1 <<<"$L") == $'"'"'id\tName\tPublisher\tStatus\tStartup impact'"'"' ]]' "startup: Windows columns"
ok '! grep -q -e mountain-lite -e baloo -e helper.desktop -e /usr/libexec <<<"$L"' "startup: internals and libexec helpers hidden"
ok 'grep -q $'"'"'^org.kde.kdeconnect.daemon.desktop\tPhone Link\tKDE\tEnabled\tNot measured$'"'"' <<<"$L"' "startup: friendly name and publisher"
ok 'grep -q $'"'"'^steam.desktop\tSteam\tValve\tEnabled\tNot measured$'"'"' <<<"$L"' "startup: user app with publisher"
run startup-set chat.desktop off
ok 'runs | grep -q $'"'"'^chat.desktop\tChat\t\tDisabled\tNone$'"'"'' "startup: disabled has no impact"
run startup-set chat.desktop on
# pages: only sensors every PC has (anything else shows "This page is missing some sensors")
P=$(dirname "$0")/../files/system/usr/share/plasma-systemmonitor
bad=$(grep -ho 'SensorIds=.*\|totalSensors=.*' "$P"/*.page | grep -o '"[^"]*"' | tr -d '"' | sort -u |
  grep -vxE 'cpu/all/usage|memory/physical/(used|total)|disk/all/(read|write)|network/all/(download|upload)')
ok '[[ -z $bad ]]' "pages use only always-present sensors${bad:+ (not: $bad)}"
Q=$(dirname "$0")/../files/system/usr/share/ksysguard/sensorfaces/org.mountain.taskmanager.list/contents/ui/FullRepresentation.qml
ok 'grep -q "model: rowModel" "$Q" && grep -q "out === root.lastText" "$Q" && grep -q "!root.busy && !listHover.hovered" "$Q"' "list updates in place, pauses under the pointer"
rm -rf "$T"; exit $rc
