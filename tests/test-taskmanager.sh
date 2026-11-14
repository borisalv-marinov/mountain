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
# Background processes: Windows names, CPU as a share of all cores (max 100 %), MB/GB, apps (app-*.scope) left out
F=$T/proc; hz=$(getconf CLK_TCK); pg=$(getconf PAGESIZE)
st() { # PID COMM TICKS RSS-MB: a /proc/PID/stat line (utime = TICKS, rss in pages)
  mkdir -p "$F/$1"; printf '%s (%s) S 1 1 1 0 -1 0 0 0 0 0 %s 0 0 0 20 0 1 0 0 0 %s 0\n' "$1" "$2" "$3" $(($4 * 1048576 / pg)) > "$F/$1/stat"
  [[ -e $F/$1/cgroup ]] || echo "0::/user.slice/session.slice/x.service" > "$F/$1/cgroup"; }
st 101 kwin_wayland 0 300; st 102 plasmashell 0 2048; st 103 "my (odd) tool" 0 5; st 104 polkit-kde-auth 0 20
st 105 dolphin 0 100; echo "0::/user.slice/app.slice/app-org.kde.dolphin@1.scope" > "$F/105/cgroup"
st 110 cupsd 0 3; st 111 gvfsd-metadata 0 1; st 112 catatonit 0 1; st 113 inotifywait 0 1; st 114 tuned-ppd 0 20; st 115 bash 0 4
st 106 kaccess 0 7; st 107 at-spi2-registr 0 3; st 108 baloorunner 0 70; st 109 baloo_file 0 30
# during the half-second sample, kwin uses a quarter of 4 cores and plasmashell more than all of them
(sleep 0.2; st 101 kwin_wayland $((hz / 2)) 300; st 102 plasmashell $((hz * 9)) 2048) &
L=$(MOUNTAIN_PROC=$F MOUNTAIN_NPROC=4 bash "$S" processes); wait
ok '[[ $(head -1 <<<"$L") == $'"'"'id\tName\tCPU\tMemory\tLocked'"'"' ]]' "processes: header"
ok 'grep -q $'"'"'^101\tDesktop Window Manager\t25.0 %\t300.0 MB\tlocked$'"'"' <<<"$L"' "processes: kwin named, CPU normalised by cores, MB"
ok 'grep -q $'"'"'^102\tWindows Explorer\t100.0 %\t2.0 GB\tlocked$'"'"' <<<"$L"' "processes: CPU capped at 100 %, GB"
ok 'grep -q $'"'"'^104\tConsent UI for administrative apps\t'"'"' <<<"$L"' "processes: 15-char comm still named"
ok 'grep -q $'"'"'^103\tmy (odd) tool\t0.0 %'"'"' <<<"$L"' "processes: unknown names kept, parentheses survive"
ok 'grep -q $'"'"'^106,107	Accessibility (2)	0.0 %	10.0 MB\tlocked$'"'"' <<<"$L"' "processes: same-name rows merged into one, ids kept"
ok 'grep -q $'"'"'^108,109	Search Indexer (2)	'"'"' <<<"$L" && ! grep -q baloorunner <<<"$L"' "processes: baloorunner named, merged"
ok 'grep -q $'"'"'^110	Print Spooler	'"'"' <<<"$L" && grep -q $'"'"'^111	File System Helper	'"'"' <<<"$L" && grep -q $'"'"'^112	Container Helper	'"'"' <<<"$L" && grep -q $'"'"'^113	Active Protection	'"'"' <<<"$L" && grep -q $'"'"'^114	Power Profiles Service	'"'"' <<<"$L" && grep -q $'"'"'^115	Command Shell	'"'"' <<<"$L"' "processes: service helpers named (cupsd, gvfsd, catatonit, inotifywait, tuned-ppd, bash)"
ok '! grep -q "^105" <<<"$L"' "processes: apps (app scopes) left out"
ok '! bash "$S" end "1; touch $T/pwned" 2>/dev/null && [[ ! -e $T/pwned ]]' "end: refuses non-numeric pid"
ok '! bash "$S" end 0 2>/dev/null && ! bash "$S" end -1 2>/dev/null' "end: refuses 0 and negative pids"
if ((EUID != 0)) && [[ -e /proc/1 && ! -O /proc/1 ]]; then ok '! bash "$S" end 1 2>/dev/null' "end: refuses another user's process"; fi
sleep 30 & p=$!
ok 'bash "$S" end $p 2>/dev/null; ! kill -0 $p 2>/dev/null' "end: ends own process"
wait $p 2>/dev/null
# session-critical rows are marked locked (End task disabled) and end refuses them
ok 'grep -q $'"'"'^104\tConsent UI for administrative apps\t[0-9.]* %\t[0-9.]* MB\tlocked$'"'"' <<<"$L"' "processes: polkit agent locked"
ok 'grep -q $'"'"'^103\tmy (odd) tool\t[0-9.]* %\t[0-9.]* MB\t$'"'"' <<<"$L" && grep -q $'"'"'^110\tPrint Spooler\t[0-9.]* %\t[0-9.]* MB\t$'"'"' <<<"$L"' "processes: ordinary rows not locked"
for c in polkit-kde-authentication-agent-1 at-spi2-registryd xdg-desktop-portal-kde pipewire-pulse wireplumber plasmalogin dbus-broker kded6 ksmserver; do
  cp /bin/sleep "$T/${c:0:15}"; "$T/${c:0:15}" 30 & p=$!; sleep 0.2
  ok '! bash "$S" end $p 2>/dev/null && kill -0 $p 2>/dev/null' "end: refuses $c"; kill $p 2>/dev/null; wait $p 2>/dev/null
done
st 120 sshd 0 2; st 121 systemd-nsresou 0 2; st 122 findmnt 0 1
L=$(MOUNTAIN_PROC=$F MOUNTAIN_NPROC=4 bash "$S" processes)
ok 'grep -q $'"'"'SSH Server'"'"' <<<"$L" && grep -q $'"'"'Namespace Resource Service'"'"' <<<"$L" && grep -q $'"'"'Drive Watcher'"'"' <<<"$L"' "processes: sshd, nsresourced, findmnt named"
# services: unit description as the name, no oneshot or image plumbing, Start/Stop only where it makes sense
mkdir -p "$T/bin"
cat > "$T/bin/systemctl" <<'SC'
#!/bin/sh
if [ "$1" = list-units ]; then for u in a b c d e f g h; do echo "$u.service loaded active running x"; done; echo "gone.service not-found inactive dead x"; exit; fi
blk() { printf 'Id=%s.service\nDescription=%s\nType=%s\nRemainAfterExit=%s\nUnitFileState=%s\nActiveState=%s\n\n' "$@"; }
blk a "Audio thing" simple no enabled active
blk b "Restore sound" oneshot no enabled inactive
blk c "Firewall" oneshot yes enabled active
blk d "Idle helper" simple no static inactive
blk e "" simple no enabled failed
blk bazzite-flatpak-manager "Flatpak" simple no enabled active
blk systemd-logind "Login" simple no static active
blk bootc-status "Bootc" simple no enabled active
SC
chmod +x "$T/bin/systemctl"
L=$(PATH=$T/bin:$PATH bash "$S" services)
ok '[[ $(head -1 <<<"$L") == $'"'"'id\tName\tStatus\tOffer'"'"' ]]' "services: header"
ok 'grep -q $'"'"'^a.service\tAudio thing\tRunning\tstop$'"'"' <<<"$L" && grep -q $'"'"'^c.service\tFirewall\tRunning\tstop$'"'"' <<<"$L" && grep -q $'"'"'^e.service\te\tFailed\tstart$'"'"' <<<"$L"' "services: description as name, start/stop offered"
ok '! grep -q -e ^b.service -e ^d.service -e ^bazzite -e ^bootc -e ^gone <<<"$L"' "services: oneshot, idle static and image units hidden"
ok 'grep -q $'"'"'^systemd-logind.service\tLogin\tRunning\t$'"'"' <<<"$L"' "services: session-critical unit offers nothing"
rm -rf "$T"; exit $rc
