#!/usr/bin/env bash
# Settings > App permissions: "Files off" removes every personal-folder grant the app has (not only home), with a fake flatpak.
set -euo pipefail
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cat > "$T/flatpak" <<'F'
#!/bin/bash
case "$1 $2" in
"info --show-permissions") printf '[Context]\nfilesystems=%s\n' "$FS" ;;
"override --user") echo "OVERRIDE ${*:3}" ;;
"list --app") printf 'com.x.y\tX\n' ;;
esac
F
chmod +x "$T/flatpak"; H=files/system/usr/libexec/mountain-app-permissions; f=0
t() { [[ $2 == "$3" ]] && echo "PASS $1" || { echo "FAIL $1: got '$2' want '$3'"; f=1; }; }
export PATH=$T:$PATH
FS='xdg-documents;xdg-desktop;~/.steam:rw;xdg-download/sub:ro;/mnt;'
t "Heroic-like app shows Files on" "$(FS=$FS bash $H list | cut -f3)" on
t "off removes each personal folder, keeps the rest" "$(FS=$FS bash $H set com.x.y files off)" "OVERRIDE --nofilesystem=home --nofilesystem=host --nofilesystem=xdg-documents --nofilesystem=xdg-desktop --nofilesystem=xdg-download/sub com.x.y"
t "an app with only its own folders shows Files off" "$(FS='~/.steam:rw;/mnt;' bash $H list | cut -f3)" off
t "a negated grant does not count" "$(FS='!home;!xdg-documents;' bash $H list | cut -f3)" off
exit $f
