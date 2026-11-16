#!/usr/bin/env bash
# Game Mode: full power while a game runs, the user's power mode back after; off means hands off.
S=$(dirname "$0")/../files/system/usr/libexec/mountain-gamemode
T=$(mktemp -d); rc=0
ok() { if eval "$1"; then echo "ok: $2"; else echo "FAIL: $2"; rc=1; fi; }
# a fake powerprofilesctl that keeps the mode in a file
printf '#!/bin/sh\n[ "$1" = get ] && cat %s/mode || echo "$2" > %s/mode\n' "$T" "$T" > "$T/ppc"; chmod +x "$T/ppc"; echo power-saver > "$T/mode"
run() { XDG_CONFIG_HOME=$T/cfg XDG_RUNTIME_DIR=$T MOUNTAIN_PPC=$T/ppc MOUNTAIN_GAMEMODE_ONCE=1 bash "$S" "$@"; }
ok '[[ $(run status | head -1) == gamemode=on ]]' "on by default"
run watch; ok '[[ $(cat "$T/mode") == power-saver ]]' "no game: power mode untouched"
printf '#!/bin/sh
sleep 30
' > "$T/wineserver"; chmod +x "$T/wineserver"; "$T/wineserver" & g=$!; sleep 0.3 # a script keeps its own name as the process name
run watch; ok '[[ $(cat "$T/mode") == performance ]]' "game running: full power"
run watch; ok '[[ $(cat "$T/mountain-gamemode.saved") == power-saver ]]' "remembers the mode from before the game"
kill $g; wait $g 2>/dev/null
run watch; ok '[[ $(cat "$T/mode") == power-saver && ! -e $T/mountain-gamemode.saved ]]' "game over: the user's mode is back"
run off >/dev/null; "$T/wineserver" & g=$!; sleep 0.3
run watch; ok '[[ $(cat "$T/mode") == power-saver ]]' "Game Mode off: no change while playing"
run on >/dev/null; run watch; ok '[[ $(cat "$T/mode") == performance ]]' "back on: full power"
run off >/dev/null; ok '[[ $(cat "$T/mode") == power-saver ]]' "turning off mid-game gives the mode back"
kill $g; wait $g 2>/dev/null
rm -rf "$T"; exit $rc
