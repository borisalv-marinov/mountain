#!/usr/bin/env bash
# Tests mountain-explorer: Desktop folders open through desktop:/ (names without ".desktop"), other paths unchanged.
S=$(dirname "$0")/../files/system/usr/libexec/mountain-explorer
T=$(mktemp -d); rc=0; trap 'rm -rf "$T"' EXIT
ok() { if eval "$1"; then echo "ok: $2"; else echo "FAIL: $2"; rc=1; fi; }
printf '#!/bin/sh\necho "$HOME/Desktop"\n' > "$T/xdg-user-dir"; printf '#!/bin/sh\nfor a; do echo "[$a]"; done\n' > "$T/dolphin"; chmod +x "$T/xdg-user-dir" "$T/dolphin"
x() { HOME=${UH:-/home/u} PATH=$T:$PATH MOUNTAIN_DOLPHIN=$T/dolphin bash "$S" "$@"; }
ok '[[ $(x "file:///home/u/Desktop/Cloud%20Gaming") == "[desktop:/Cloud Gaming]" ]]' "a desktop folder from Plasma opens through desktop:/"
ok '[[ $(x /home/u/Desktop/Coding) == "[desktop:/Coding]" ]]' "a plain path too"
ok '[[ $(x /home/u/Desktop) == "[desktop:/]" ]]' "the Desktop itself"
ok '[[ $(x /home/u/Documents "--new-window") == $'"'"'[/home/u/Documents]\n[--new-window]'"'"' ]]' "other folders and options unchanged"
ok '[[ $(x /home/u/DesktopX) == "[/home/u/DesktopX]" ]]' "a folder that only starts with the same letters is unchanged"
mkdir -p "$T/var/home/u/Desktop/Coding"; ln -s var/home "$T/home"
ok '[[ $(UH=$T/var/home/u x "$T/home/u/Desktop/Coding") == "[desktop:/Coding]" ]]' "a path through the /home link (Bazzite: /home -> /var/home)"
exit $rc
