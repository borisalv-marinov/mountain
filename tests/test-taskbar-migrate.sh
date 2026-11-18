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
# Desktop right-click menu: Plasma's KDE-only rows off from the first sign-in (no appletsrc yet), once per account
mkdir -p "$T/bin" "$T/new"; printf '#!/bin/sh\necho "$*" >> "%s/kw.log"\n' "$T" > "$T/bin/kwriteconfig6"; chmod +x "$T/bin/kwriteconfig6"
runm() { (HOME=$T/new XDG_CONFIG_HOME=$T/new/cfg XDG_STATE_HOME=$T/new/state PATH=$T/bin:$PATH; . "$S") >/dev/null 2>&1; }
runm
for k in _logout _lock_screen "desktop edit mode"; do
  ok 'grep -qF -- "--group RightButton;NoModifier --key $k false" "$T/kw.log"' "desktop menu: $k off at the first sign-in"
done
ok '[[ -e $T/new/state/mountain/migrated-desktopmenu ]]' "desktop menu: done marker written"
: > "$T/kw.log"; runm
ok '[[ ! -s $T/kw.log ]]' "desktop menu: only once (a later change by the user stays)"
rm -rf "$T"; exit $rc
