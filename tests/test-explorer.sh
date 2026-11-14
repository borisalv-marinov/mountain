#!/usr/bin/env bash
# Tests mountain-explorer: Desktop folders open through desktop:/ (names without ".desktop"), other paths unchanged.
S=$(dirname "$0")/../files/system/usr/libexec/mountain-explorer
T=$(mktemp -d); rc=0; trap 'rm -rf "$T"' EXIT
ok() { if eval "$1"; then echo "ok: $2"; else echo "FAIL: $2"; rc=1; fi; }
printf '#!/bin/sh\necho "$HOME/Desktop"\n' > "$T/xdg-user-dir"; printf '#!/bin/sh\nfor a; do echo "[$a]"; done\n' > "$T/dolphin"; chmod +x "$T/xdg-user-dir" "$T/dolphin"
printf '#!/bin/sh\ncat <<X\n/run/media/u/USB\\x20stick /dev/sdb1\n/run/media/u/Games /dev/sda2\n/boot /dev/sda1\nX\n' > "$T/findmnt" # findmnt -r writes a space as \x20
printf '#!/bin/sh\ncase "$2 $3" in "LABEL /dev/sda2") echo Games;; "RM /dev/sdb1") echo 1;; esac\n' > "$T/lsblk"; chmod +x "$T/findmnt" "$T/lsblk"
x() { XDG_DATA_HOME=$T/data HOME=${UH:-/home/u} PATH=$T:$PATH MOUNTAIN_DOLPHIN=$T/dolphin bash "$S" "$@"; }
ok '[[ $(x "file:///home/u/Desktop/Cloud%20Gaming") == "[desktop:/Cloud Gaming]" ]]' "a desktop folder from Plasma opens through desktop:/"
ok '[[ $(x /home/u/Desktop/Coding) == "[desktop:/Coding]" ]]' "a plain path too"
ok '[[ $(x /home/u/Desktop) == "[desktop:/]" ]]' "the Desktop itself"
ok '[[ $(x /home/u/Documents "--new-window") == $'"'"'[/home/u/Documents]\n[--new-window]'"'"' ]]' "other folders and options unchanged"
ok '[[ $(x /home/u/DesktopX) == "[/home/u/DesktopX]" ]]' "a folder that only starts with the same letters is unchanged"
mkdir -p "$T/var/home/u/Desktop/Coding"; ln -s var/home "$T/home"
ok '[[ $(UH=$T/var/home/u x "$T/home/u/Desktop/Coding") == "[desktop:/Coding]" ]]' "a path through the /home link (Bazzite: /home -> /var/home)"
P=$T/data/mountain/This\ PC; x --this-pc
ok '[[ $(ls "$P") == $'"'"'Games (D:)
Local Disk (C:)
USB Drive (E:)'"'"' && $(readlink "$P/Local Disk (C:)") == / && $(readlink "$P/Games (D:)") == /run/media/u/Games ]]' "This PC: C: system disk, other drives lettered D:, E: with their labels (USB without a label: USB Drive)"
ok 'grep -qx "SortRole=destination" "$P/.directory" && [[ $(for f in "$P"/*; do echo "$(readlink "$f") $f"; done | sort | sed "s/.*\///") == $'"'"'Local Disk (C:)
Games (D:)
USB Drive (E:)'"'"' ]]' "This PC: Dolphin sorts by link target, giving C:, D:, E: (not by name)"
ok '[[ $(readlink "$P/USB Drive (E:)") == "/run/media/u/USB stick" ]]' "a mount point with a space is linked right"
exit $rc
