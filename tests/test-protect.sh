#!/usr/bin/env bash
# Tests Active Protection's "unverified" rule and the review actions (no ClamAV needed).
S=$(dirname "$0")/../files/system/usr/libexec/mountain-protect
T=$(mktemp -d); rc=0
ok() { if eval "$1"; then echo "ok: $2"; else echo "FAIL: $2"; rc=1; fi; }
eval "$(sed -n '/^is_unverified()/,/^}/p' "$S")"
allowed=$T/allowed
mkdir -p "$T/.config/autostart"
printf '#!/bin/sh\necho hi\n' > "$T/run-me"; echo text > "$T/notes.txt"; echo x > "$T/setup.exe"; printf '[Desktop Entry]\n' > "$T/.config/autostart/evil.desktop"
ok '[[ $(is_unverified "$T/run-me") == script ]]' "a script with a shebang is unverified"
ok '[[ $(is_unverified "$T/setup.exe") == "program or script" ]]' "an .exe is unverified"
ok '[[ $(is_unverified "$T/.config/autostart/evil.desktop") == "starts at sign-in" ]]' "a new autostart entry is flagged"
ok '! is_unverified "$T/notes.txt" >/dev/null' "a text file is fine"
sha256sum "$T/run-me" | cut -d' ' -f1 > "$allowed"
ok '! is_unverified "$T/run-me" >/dev/null' "an allowed file is no longer flagged"
H=$T/home; mkdir -p "$H"; printf '%s\tscript\n' "$T/setup.exe" > /dev/null
ok '! HOME=$H XDG_DATA_HOME= bash "$S" delete "$T/notes.txt" 2>/dev/null && [[ -e $T/notes.txt ]]' "delete refuses files not in the review list"
eval "$(sed -n '/^inlist()/p; /^drop()/p' "$S")"; unv=$T/unverified; : > "$unv"
for n in 'a|b' "x|e touch $T/pwned #.sh" '$(id)' '.*' keep; do printf '%s	script
' "/d/$n" >> "$unv"; done
for n in 'a|b' "x|e touch $T/pwned #.sh" '$(id)' '.*'; do drop "/d/$n"; done
ok '[[ ! -e $T/pwned && $(cat "$unv") == "/d/keep	script" ]] && ! inlist /d/kee' "review list edits are exact and never run file names"
# commands given a path through a link (/home -> /var/home) still find the entry the watcher stored under the real path
mkdir -p "$T/real/d" "$T/data/mountain/protect"; ln -s "$T/real" "$T/link"; echo x > "$T/real/d/f.sh"
printf '%s	script
' "$T/real/d/f.sh" > "$T/data/mountain/protect/unverified"
[[ -L $T/link ]] && ok 'HOME=$T/real XDG_DATA_HOME=$T/data bash "$S" delete "$T/link/d/f.sh" && [[ ! -e $T/real/d/f.sh && ! -s $T/data/mountain/protect/unverified ]]' "delete through a linked path finds the real entry"
# the scan path: systemd-run is a stand-in that "finds" files containing EVIL (stdin for "-"), like clamscan's report-only mode
B=$T/bin; H=$T/h; D=$T/d; mkdir -p "$B" "$H/Downloads/node_modules" "$H/proj/node_modules"
cat > "$B/systemd-run" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" | grep -qx 'Environment=MOUNTAIN_SCAN_REPORT_ONLY=1' || { echo "av_result=error"; exit 0; }
printf '%s\n' "$@" | grep -q '^InaccessiblePaths=.*/bus"$' || { echo "av_result=error"; exit 0; }
while [[ $1 != /usr/libexec/mountain-security ]]; do shift; done; shift 3; r=clean
for f; do if [[ $f == - ]]; then grep -q EVIL && { echo "stdin: Evil FOUND"; r=found; }; elif grep -q EVIL "$f"; then echo "$f: Evil FOUND"; r=found; fi; done
echo "av_result=$r"
STUB
printf '#!/bin/sh\n' > "$B/notify-send"; chmod +x "$B/systemd-run" "$B/notify-send"
echo EVIL > "$H/Downloads/node_modules/a.zip"; echo EVIL > "$H/proj/node_modules/b.zip"; echo fine > "$H/Downloads/ok.zip"
pc() { HOME=$H XDG_DATA_HOME=$D XDG_RUNTIME_DIR=$T/run PATH=$B:$PATH bash "$S" check "$@" >/dev/null 2>&1; }
mkdir -p "$T/run"; pc "$H/Downloads/node_modules/a.zip" "$H/proj/node_modules/b.zip" "$H/Downloads/ok.zip"
ok '[[ ! -e $H/Downloads/node_modules/a.zip && -e $D/mountain/quarantine/a.zip && -e $H/Downloads/ok.zip ]]' "a threat in Downloads is quarantined even inside a node_modules folder"
ok '[[ -e $H/proj/node_modules/b.zip ]]' "node_modules outside Downloads is still skipped"
if touch "$H/Downloads/t"$'\t'"x.zip" 2>/dev/null; then # tabs in names: not on Windows file systems
  echo EVIL > "$H/Downloads/t"$'\t'"x.zip"; pc "$H/Downloads/t"$'\t'"x.zip"
  ok '[[ ! -e $H/Downloads/t$'"'\t'"'x.zip && -e $D/mountain/quarantine/t_x.zip ]] && ! grep -q "t	x" "$D/mountain/protect/unverified" 2>/dev/null' "a file with a tab in its name is scanned and quarantined under a plain name"
fi
rm -rf "$T"; exit $rc
