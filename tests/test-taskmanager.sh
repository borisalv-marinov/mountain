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
# installed apps Windows would list (Steam, Discord...) show as Disabled even with no autostart entry; on copies the launcher
mkdir -p "$T/apps"; printf '[Desktop Entry]\nName=Discord\nExec=/usr/bin/flatpak run com.discordapp.Discord\n' > "$T/apps/com.discordapp.Discord.desktop"
printf '[Desktop Entry]\nName=Steam\nExec=steam %%U\n' > "$T/apps/com.valvesoftware.Steam.desktop"
runa() { MOUNTAIN_APPS_DIRS=$T/apps run "$@"; }
ok 'runa startup | grep -q $'"'"'^com.discordapp.Discord.desktop\tDiscord\tDisabled'"'"'' "startup: installed Discord offered as Disabled"
runa startup-set com.discordapp.Discord.desktop on
ok 'grep -qx "X-Mountain-Added=true" "$T/home/.config/autostart/com.discordapp.Discord.desktop" && runa startup | grep -q $'"'"'^com.discordapp.Discord.desktop\tDiscord\tEnabled'"'"'' "startup: on copies the launcher, shows Enabled"
runa startup-set com.discordapp.Discord.desktop off
ok '[[ ! -e $T/home/.config/autostart/com.discordapp.Discord.desktop ]] && runa startup | grep -q "^com.discordapp.Discord.desktop.*Disabled"' "startup: off removes the copy, offered again"
runa startup-set com.valvesoftware.Steam.desktop on
ok 'grep -qx "Exec=steam -silent %U" "$T/home/.config/autostart/com.valvesoftware.Steam.desktop"' "startup: Steam starts in the tray"
ok '[[ $(runa startup | grep -c "^steam.desktop") == 1 ]]' "startup: an app already in autostart is not offered twice"
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
ok '[[ $(head -1 <<<"$L") == $'"'"'id\tName\tCPU\tMemory\tLocked\tIcon'"'"' ]]' "processes: header"
ok 'grep -q $'"'"'^101\tDesktop Window Manager\t25.0 %\t300.0 MB\tlocked\tpreferences-system-windows$'"'"' <<<"$L"' "processes: kwin named, CPU normalised by cores, MB"
ok 'grep -q $'"'"'^102\tWindows Explorer\t100.0 %\t2.0 GB\tlocked\tsystem-file-manager$'"'"' <<<"$L"' "processes: CPU capped at 100 %, GB"
ok 'grep -q $'"'"'^104\tConsent UI for administrative apps\t'"'"' <<<"$L"' "processes: 15-char comm still named"
ok 'grep -q $'"'"'^103\tmy (odd) tool\t0.0 %'"'"' <<<"$L"' "processes: unknown names kept, parentheses survive"
ok 'grep -q $'"'"'^103	my (odd) tool	.*	my (odd) tool$'"'"' <<<"$L"' "processes: icon column is the program name when no icon is mapped (Task Manager falls back to the generic program icon)"
ok 'grep -q $'"'"'^106,107	Accessibility (2)	0.0 %	10.0 MB\tlocked\tpreferences-desktop-accessibility$'"'"' <<<"$L"' "processes: same-name rows merged into one, ids kept"
ok 'grep -q $'"'"'^108,109	Search Indexer (2)	'"'"' <<<"$L" && ! grep -q baloorunner <<<"$L"' "processes: baloorunner named, merged"
ok 'grep -q $'"'"'^110	Print Spooler	'"'"' <<<"$L" && grep -q $'"'"'^111	File System Helper	'"'"' <<<"$L" && grep -q $'"'"'^112	Container Helper	'"'"' <<<"$L" && grep -q $'"'"'^113	Active Protection	'"'"' <<<"$L" && grep -q $'"'"'^114	Power Profiles Service	'"'"' <<<"$L" && grep -q $'"'"'^115	Command Shell	'"'"' <<<"$L"' "processes: service helpers named (cupsd, gvfsd, catatonit, inotifywait, tuned-ppd, bash)"
ok '! grep -q "^105" <<<"$L"' "processes: apps (app scopes) left out"
# Apps table: scope, flatpak scope, D-Bus-activated service, autostart service (background)
st 130 firefox 0 10; echo "0::/user.slice/user-1000.slice/user@1000.service/app.slice/app-firefox-0123abcd.scope" > "$F/130/cgroup"
st 131 gwenview 0 10; echo '0::/user.slice/user-1000.slice/user@1000.service/app.slice/app-flatpak-org.kde.plasma\x2dsystemmonitor-0123abcd.scope' > "$F/131/cgroup"
st 132 dolphin 0 10; echo '0::/user.slice/user-1000.slice/user@1000.service/app.slice/app-dbus\x2d:1.23\x2dorg.kde.dolphin@0.service' > "$F/132/cgroup"
st 133 steam 0 10; echo '0::/user.slice/user-1000.slice/user@1000.service/app.slice/app-steam@autostart.service' > "$F/133/cgroup"
# KIO with systemd >= 250 (Start, taskbar): app-ID@UUID.service, UUID as 32 hex digits (kio systemdprocessrunner.cpp)
st 134 kate 0 10; echo '0::/user.slice/user-1000.slice/user@1000.service/app.slice/app-org.kde.kate@0123456789abcdef0123456789abcdef.service' > "$F/134/cgroup"
A=$(MOUNTAIN_PROC=$F MOUNTAIN_NPROC=4 MOUNTAIN_APPS_DIRS=$T/none bash "$S" apps | cut -f1,2)
ok 'grep -q $'"'"'^130\tfirefox$'"'"' <<<"$A" && grep -q $'"'"'^131\torg.kde.plasma-systemmonitor$'"'"' <<<"$A"' "apps: app scope and flatpak scope listed by app id"
ok 'grep -q $'"'"'^132\torg.kde.dolphin$'"'"' <<<"$A"' "apps: D-Bus-activated service listed by app id"
ok 'grep -q $'"'"'^134	org.kde.kate$'"'"' <<<"$A"' "apps: app started from Start or the taskbar (app-ID@UUID.service) listed"
# Task Manager runs the helper through sh -c, which execs it: the parent is then Task Manager itself, and must stay a row
A2=$(MOUNTAIN_PROC=$F MOUNTAIN_NPROC=4 MOUNTAIN_APPS_DIRS=$T/none bash -c 'mkdir -p "$1/$$"; printf "%s (plasma-systemmo) S 1 1 1 0 -1 0 0 0 0 0 0 0 0 0 20 0 1 0 0 0 100 0\n" $$ > "$1/$$/stat"; echo "0::/user.slice/user-1000.slice/user@1000.service/app.slice/app-org.kde.plasma\x2dsystemmonitor@0123456789abcdef0123456789abcdef.service" > "$1/$$/cgroup"; bash "$2" apps; rm -r "${1:?}/$$"' _ "$F" "$S" | cut -f2)
ok 'grep -qx org.kde.plasma-systemmonitor <<<"$A2"' "apps: Task Manager itself (the helper's parent) listed"
ok '! grep -q "^133" <<<"$A" && MOUNTAIN_PROC=$F bash "$S" processes | grep -q "^133"' "apps: autostart service stays a background process"
# apps started with systemd-run (no app-*.scope): listed by launcher name when the unit runs a launcher's program; other run-* units stay background
mkdir -p "$T/lapps"; printf '[Desktop Entry]\nName=Web Browser\nExec=/usr/lib/firefox/firefox %%u\n' > "$T/lapps/org.mozilla.firefox.desktop"
printf '[Desktop Entry]\nName=Hidden Helper\nNoDisplay=true\nExec=helperd\n' > "$T/lapps/helper.desktop"
st 140 firefox 0 10; st 141 "Isolated Web Co" 0 10; st 142 endtasktest 0 1; st 143 helperd 0 1
for n in 140 141; do echo '0::/user.slice/user-1000.slice/user@1000.service/app.slice/run-u123.service' > "$F/$n/cgroup"; done
for n in 142 143; do echo "0::/user.slice/user-1000.slice/user@1000.service/app.slice/run-u$n.service" > "$F/$n/cgroup"; done
RA=$(MOUNTAIN_PROC=$F MOUNTAIN_NPROC=4 MOUNTAIN_APPS_DIRS=$T/lapps bash "$S" apps | cut -f1,2)
ok 'grep -q $'"'"'^140,141\tWeb Browser$'"'"' <<<"$RA"' "apps: a systemd-run unit of a launcher's program is one app row, named like Windows"
ok '! grep -qE "^14[23]" <<<"$RA" && MOUNTAIN_PROC=$F MOUNTAIN_APPS_DIRS=$T/lapps bash "$S" processes | grep -q "^142" && ! MOUNTAIN_PROC=$F MOUNTAIN_APPS_DIRS=$T/lapps bash "$S" processes | grep -qE "^(140|141)"' "apps: run-* unit with no launcher (or a hidden one) stays background"
# Users: people only (uid >= 1000), never root or system accounts
mkdir -p "$T/lbin"; printf '#!/bin/sh\nif [ "$1" = list-users ]; then printf "0 root 1 active\\n1000 marin 1 active\\n977 sddm 1 active\\n"; fi\n' > "$T/lbin/loginctl"; chmod +x "$T/lbin/loginctl"
U=$(PATH=$T/lbin:$PATH bash "$S" users | cut -f1,2)
ok 'grep -q $'"'"'^1000\tmarin$'"'"' <<<"$U" && ! grep -qE "root|sddm" <<<"$U"' "users: only people (uid >= 1000), not root"
ok '! bash "$S" end "1; touch $T/pwned" 2>/dev/null && [[ ! -e $T/pwned ]]' "end: refuses non-numeric pid"
ok '! bash "$S" end 0 2>/dev/null && ! bash "$S" end -1 2>/dev/null' "end: refuses 0 and negative pids"
if ((EUID != 0)) && [[ -e /proc/1 && ! -O /proc/1 ]]; then ok '! bash "$S" end 1 2>/dev/null' "end: refuses another user's process"; fi
sleep 30 & p=$!
ok 'bash "$S" end $p 2>/dev/null; ! kill -0 $p 2>/dev/null' "end: ends own process"
wait $p 2>/dev/null
# session-critical rows are marked locked (End task disabled) and end refuses them
ok 'grep -q $'"'"'^104\tConsent UI for administrative apps\t[0-9.]* %\t[0-9.]* MB\tlocked\tdialog-password$'"'"' <<<"$L"' "processes: polkit agent locked"
ok 'grep -q $'"'"'^103\tmy (odd) tool\t[0-9.]* %\t[0-9.]* MB\t\t[^\t]*$'"'"' <<<"$L" && grep -q $'"'"'^110\tPrint Spooler\t[0-9.]* %\t[0-9.]* MB\t\t[^\t]*$'"'"' <<<"$L"' "processes: ordinary rows not locked"
for c in polkit-kde-authentication-agent-1 at-spi2-registryd xdg-desktop-portal-kde pipewire-pulse wireplumber plasmalogin dbus-broker kded6 ksmserver; do
  python3 -c 'import ctypes, sys, time; ctypes.CDLL(None).prctl(15, sys.argv[1].encode()[:15], 0, 0, 0); time.sleep(30)' "$c" & p=$!; sleep 0.5 # comm set with prctl(PR_SET_NAME): a copied sleep can be a multi-call binary that exits
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
# Bulgarian session: friendly names in Bulgarian (the English ones stay above)
LB=$(LANGUAGE=bg@mountain:bg MOUNTAIN_PROC=$F MOUNTAIN_NPROC=4 bash "$S" processes)
ok 'grep -q $'"'"'^104	Интерфейс за администраторско съгласие	'"'"' <<<"$LB" && grep -q $'"'"'^113	Активна защита	'"'"' <<<"$LB" && grep -q $'"'"'^115	Команден шел	'"'"' <<<"$LB" && grep -q $'"'"'^106,107	Достъпност (2)	'"'"' <<<"$LB"' "bg: names in Bulgarian, merged rows too"
ok '[[ $(head -1 <<<"$LB") == $'"'"'id	Name	CPU	Memory	Locked	Icon'"'"' ]] && grep -q "^103.my (odd) tool" <<<"$LB"' "bg: header kept for the face to translate, unknown names kept"
ok 'grep -q "tr(\"End task\")" "$(dirname "$S")/../share/ksysguard/sensorfaces/org.mountain.taskmanager.list/contents/ui/FullRepresentation.qml" && grep -q "Процесор" "$(dirname "$S")/../share/ksysguard/sensorfaces/org.mountain.taskmanager.list/contents/ui/FullRepresentation.qml"' "bg: face translates headers and End task"
rm -rf "$T"; exit $rc
