#!/usr/bin/env bash
# Accounts made before v7.1: Plasma's spacers become Mountain's taskbar space once, in place, with their settings.
S=$(dirname "$0")/../files/system/etc/xdg/plasma-workspace/env/mountain-migrate.sh
T=$(mktemp -d); rc=0
ok() { if eval "$1"; then echo "ok: $2"; else echo "FAIL: $2"; rc=1; fi; }
mkdir -p "$T/cfg" "$T/plasmoids/org.mountain.taskbarspace"
rc_file=$T/cfg/plasma-org.kde.plasma.desktop-appletsrc
printf '[Containments][2][Applets][3]\nplugin=org.kde.plasma.panelspacer\n\n[Containments][2][Applets][3][Configuration][General]\nexpanding=false\nlength=162\n\n[Containments][2][Applets][4]\nplugin=org.kde.plasma.kickoff\n' > "$rc_file"
run() { (HOME=$T XDG_CONFIG_HOME=$T/cfg XDG_STATE_HOME=$T/state MOUNTAIN_PLASMOIDS=$T/plasmoids; . "$S"; echo "still running") ; }
ok '[[ $(run) == "still running" ]]' "sourcing it never ends the session script"
ok 'grep -qx plugin=org.mountain.taskbarspace "$rc_file" && ! grep -q panelspacer "$rc_file"' "the spacer becomes Mountain's taskbar space"
ok 'grep -qx length=162 "$rc_file" && grep -qx plugin=org.kde.plasma.kickoff "$rc_file"' "its settings and the other applets stay"
sed -i 's/org.mountain.taskbarspace/org.kde.plasma.panelspacer/' "$rc_file"; run >/dev/null
ok 'grep -qx plugin=org.kde.plasma.panelspacer "$rc_file"' "only once: a spacer added later by the user stays"
rm -rf "$T/state"; rm -rf "$T/plasmoids/org.mountain.taskbarspace"; run >/dev/null
ok 'grep -qx plugin=org.kde.plasma.panelspacer "$rc_file"' "nothing changes when Mountain's applet is missing"
rm -rf "$T"; exit $rc
