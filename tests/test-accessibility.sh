#!/usr/bin/env bash
# Tests mountain-accessibility (Settings > Accessibility) with stub KDE tools: a tiny config store stands in for
# kwriteconfig6/kreadconfig6/gsettings, other tools only log their arguments. No Plasma needed (CI lint job).
set -uo pipefail
S=$(cd "$(dirname "$0")/.." && pwd)/files/system/usr/libexec/mountain-accessibility
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"; export LOG=$T/log STORE=$T/store HOME=$T/home XDG_STATE_HOME=$T/state PATH="$T/bin:$PATH"
mkstub() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$T/bin/$1"; chmod +x "$T/bin/$1"; }
# kwriteconfig6 --file F --group G [--group G2] --key K [--type T] [--notify] VALUE  ->  store line F/G/K=VALUE
mkstub kwriteconfig6 'echo "kwriteconfig6 $*" >> "$LOG"; f= g= k=; while (($#>1)); do case $1 in --file) f=$2; shift 2;; --group) g=$g$2; shift 2;; --key) k=$2; shift 2;; --type) shift 2;; --notify) shift;; *) break;; esac; done
grep -v "^$f/$g/$k=" "$STORE" 2>/dev/null > "$STORE.n"; echo "$f/$g/$k=$1" >> "$STORE.n"; mv "$STORE.n" "$STORE"'
mkstub kreadconfig6 'f= g= k= d=; while (($#)); do case $1 in --file) f=$2;; --group) g=$g$2;; --key) k=$2;; --default) d=$2;; esac; shift 2; done
v=$(grep -m1 "^$f/$g/$k=" "$STORE" 2>/dev/null) && echo "${v#*=}" || echo "$d"'
mkstub gsettings 'echo "gsettings $*" >> "$LOG"; case $1 in set) grep -v "^gs/$2/$3=" "$STORE" 2>/dev/null > "$STORE.n"; echo "gs/$2/$3=$4" >> "$STORE.n"; mv "$STORE.n" "$STORE";;
get) v=$(grep -m1 "^gs/$2/$3=" "$STORE" 2>/dev/null) && echo "${v#*=}" || echo false;; esac'
mkstub plasma-apply-cursortheme 'echo "plasma-apply-cursortheme $*" >> "$LOG"; [[ $2 == --size ]] && kwriteconfig6 --file kcminputrc --group Mouse --key cursorSize "$3"'
mkstub setsid 'echo "setsid $*" >> "$LOG"; [[ $* == *orca* ]] && touch "$T/orca-running"'
mkstub pkill 'echo "pkill $*" >> "$LOG"; [[ $* == *orca* ]] && rm -f "$T/orca-running"; true'
mkstub pgrep '[[ -e $T/orca-running ]] && echo 4242'
mkstub id '[[ $1 == -u ]] && echo "${FAKE_UID:-1000}" || /usr/bin/id "$@"'
export T
for c in dbus-send; do mkstub $c "echo \"$c \$*\" >> \"\$LOG\""; done

rc=0
ok() { echo "ok: $1"; }
bad() { echo "FAIL: $1"; rc=1; }
run() { : > "$LOG"; bash "$S" "$@" > "$T/out" 2>&1; }
has() { grep -qxF -- "$1" "$STORE" && ok "$2" || bad "$2 (store has no '$1')"; }
logged() { grep -qF -- "$1" "$LOG" && ok "$2" || bad "$2 (no call '$1')"; }
st() { local o; o=$(bash "$S" status); grep -qx -- "$1" <<<"$o" && ok "status $1" || bad "status: want $1, got $(bash "$S" status | tr '\n' ' ')"; }

st narrator=off; st filter=off; st cursor=24; st sticky=off; st animations=on

run narrator on
has kaccessrc/ScreenReader/Enabled=true "narrator on saves the setting kaccess reads"
has gs/org.gnome.desktop.a11y.applications/screen-reader-enabled=true "narrator on tells Orca and GTK"
logged "setsid -f orca --replace" "narrator on starts Orca detached"
st narrator=on
run narrator toggle
has kaccessrc/ScreenReader/Enabled=false "narrator toggle turns it off again"
has gs/org.gnome.desktop.a11y.applications/screen-reader-enabled=false "narrator off: Orca quits on the gsettings key"
logged "pkill -u" "narrator off also stops a stuck Orca"
st narrator=off

run filter tritanopia
has kwinrc/Effect-colorblindnesscorrection/Mode=2 "blue-yellow filter is mode 2"
has kwinrc/Plugins/colorblindnesscorrectionEnabled=true "filter on enables the KWin effect"
logged "org.kde.KWin.reconfigure" "filter on reaches KWin"
st filter=tritanopia
run filter toggle
has kwinrc/Plugins/colorblindnesscorrectionEnabled=false "Win+Ctrl+C turns the filter off"
st filter=off
run filter toggle
st filter=tritanopia # Win+Ctrl+C brings back the last filter used
run filter off; rm -rf "$XDG_STATE_HOME"; run filter toggle
st filter=deuteranopia # nothing chosen yet: the most common one (red-green, green weak)

run cursor 48
logged "plasma-apply-cursortheme breeze_cursors --size 48" "pointer size goes through Plasma's own tool"
has gs/org.gnome.desktop.interface/cursor-size=48 "pointer size reaches GTK apps"
st cursor=48

run sticky on
logged "--file kaccessrc --group Keyboard --key StickyKeys --notify" "sticky keys use --notify (KWin's watcher applies it live)"
st sticky=on

run animations off; has kdeglobals/KDE/AnimationDurationFactor=0 "animations off"; st animations=off
run animations on; has kdeglobals/KDE/AnimationDurationFactor=0.75 "animations on = Mountain's default 0.75"; st animations=on

run zoom in; logged "invokeShortcut string:view_zoom_in" "Magnifier zoom in is KWin's own action"
run zoom off; logged "invokeShortcut string:view_actual_size" "Win+Esc: back to normal"

touch "$T/orca-running"; st narrator=on # Orca started some other way (kaccess, Meta+Alt+S): the switch says On
run narrator toggle; [[ -e $T/orca-running ]] && bad "toggle must stop a running Orca" || ok "toggle follows the real Orca process"
mkstub plasma-apply-cursortheme 'echo "plasma-apply-cursortheme $*" >> "$LOG"; exit 1'
run cursor 64; e=$?; [[ $e != 0 ]] && ok "a failed live pointer change is still an error" || bad "cursor failure exit 0"
st cursor=64 # the size is saved first, so Plasma uses it at the next start even when the live change fails (no display: Qt aborts)
has gs/org.gnome.desktop.interface/cursor-size=64 "GTK size saved even when the live change fails"
FAKE_UID=0 run narrator on; e=$?; [[ $e == 3 ]] && ok "refuses to run as root (Orca must never be root)" || bad "root exit $e, want 3"
for a in "" "bogus" "narrator maybe" "cursor 999" "cursor 48;id" "filter red" "animations" "zoom out"; do
  # shellcheck disable=SC2086
  run $a; e=$?; [[ $e == 2 ]] && ok "rejects '$a'" || bad "'$a' exit $e, want 2"
done
[[ $(bash "$S" status | wc -l) == 5 ]] && ok "status has five lines" || bad "status line count"
exit $rc
