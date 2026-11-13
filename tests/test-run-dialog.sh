#!/usr/bin/env bash
# Tests mountain-run (Win+R): what each kind of entry opens, the error text, and the history.
r="$(cd "$(dirname "$0")/.." && pwd)/files/system/usr/libexec/mountain-run"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export HOME=$tmp XDG_STATE_HOME=$tmp/state XDG_DATA_HOME=$tmp/data XDG_DATA_DIRS=$tmp/sys MOUNTAIN_RUN_DRY=1
mkdir -p "$tmp/sys/applications" "$tmp/My Folder"
printf '[Desktop Entry]\nType=Application\nName=Firefox\nExec=firefox\n' > "$tmp/sys/applications/org.mozilla.firefox.desktop"
# an id that is never a program on PATH (CI runners have a real firefox)
printf '[Desktop Entry]\nType=Application\nName=Zz Viewer\nExec=zzviewer\n' > "$tmp/sys/applications/org.example.zzviewer.desktop"
rc=0
ok() { if eval "$1"; then echo "ok: $2"; else echo "FAIL: $2"; rc=1; fi; }
ok '[[ $(bash "$r" https://example.com) == "xdg-open https://example.com" ]]' "internet address"
ok '[[ $(bash "$r" www.example.com) == "xdg-open https://www.example.com" ]]' "www address gets https"
ok '[[ $(bash "$r" "~/My Folder") == "xdg-open $tmp/My Folder" ]]' "folder under home"
ok '[[ $(bash "$r" "\"$tmp/My Folder\"") == "xdg-open $tmp/My Folder" ]]' "quoted path from Browse"
ok '[[ $(bash "$r" "  bash -c true ") == "bash -c bash -c true" ]]' "program with arguments, spaces trimmed"
ok '[[ $(bash "$r" Firefox) == "gio launch $tmp/sys/applications/org.mozilla.firefox.desktop" ]]' "app by name (Flatpak)"
ok '[[ $(bash "$r" zzviewer) == "gio launch $tmp/sys/applications/org.example.zzviewer.desktop" ]]' "app by id"
out=$(bash "$r" no-such-program-xyz); e=$?
ok '[[ $e == 1 && $out == *"can'"'"'t find '"'"'no-such-program-xyz'"'"'"* ]]' "unknown name: error text, exit 1"
ok '[[ $(bash "$r" --history | head -n 1) == zzviewer ]]' "newest first in history"
ok '[[ $(bash "$r" --history | grep -cx "Firefox") == 1 ]] && ! bash "$r" --history | grep -q no-such' "history: one entry each, failures not kept"
bash "$r" firefox >/dev/null
ok '[[ $(bash "$r" --history | grep -cix firefox) == 2 ]]' "repeat moves to the top, no duplicate"
ok '[[ $(bash "$r" control) == "sh -c sleep 0.5; exec plasmawindowed org.mountain.settings" ]]' "control opens Settings after Run closes"
exit $rc
