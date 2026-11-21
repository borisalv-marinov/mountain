#!/usr/bin/env bash
# The real Active Protection watcher end to end (inotifywait; ClamAV and notifications faked): the VM order of events,
# a killed watcher restarted, an extracted folder, then a second one with an EICAR named .txt that must be quarantined.
export MOUNTAIN_NOTIFY_PLAIN=1 # the scripts send notices from a background process otherwise (click action); these tests read the fake notify-send log at once
S=$(cd "$(dirname "$0")/.." && pwd)/files/system/usr/libexec/mountain-protect
command -v inotifywait >/dev/null || { echo "FAIL: inotifywait missing (apt install inotify-tools)"; exit 1; }
T=$(mktemp -d); rc=0
ok() { if eval "$1"; then echo "ok: $2"; else echo "FAIL: $2"; rc=1; fi; }
export HOME=$T/home XDG_RUNTIME_DIR=$T/run PATH=$T/bin:$PATH
mkdir -p "$HOME/Documents" "$XDG_RUNTIME_DIR" "$T/bin"; chmod 700 "$XDG_RUNTIME_DIR"
# systemd-run stub: the scan unit runs here; reports like mountain-security scan (FILE: NAME FOUND, then av_result=)
cat > "$T/bin/systemd-run" <<'EOF'
#!/usr/bin/env bash
while [[ $1 != /usr/libexec/mountain-security ]]; do shift; done; shift 3; r=clean
for f; do if [[ $f == - ]]; then grep -q EICAR-STANDARD && r=found; elif grep -q EICAR-STANDARD "$f"; then echo "$f: Eicar-Signature FOUND"; r=found; fi; done
echo "av_result=$r"
EOF
printf '#!/bin/sh\necho "$@" >> %s/notes\n' "$T" > "$T/bin/notify-send"
printf '#!/bin/sh\nexec sleep 600\n' > "$T/bin/findmnt" # no new drives
chmod +x "$T/bin"/*
log=$T/log; start() { bash "$S" daemon >> "$log" 2>&1 & d=$!; sleep 2; }
waitfor() { for _ in $(seq 60); do eval "$1" && return 0; sleep 1; done; return 1; }
start
pkill -P "$d" -x inotifywait; wait "$d"; e=$?; ok '[[ $e == 1 ]] && grep -q "a watcher stopped" "$log"' "a killed watcher stops the service (systemd restarts it)"
start
D=$HOME/Documents
mkdir "$D/ext"; for i in 1 2 3 4 5 6; do echo "note$i" > "$D/ext/f$i.txt"; done
ok 'waitfor "grep -q \"checking 6 file\" \"$log\""' "after a restart, an extracted folder gets one scan"
rm -rf "$D/ext"
mkdir "$D/ext2"; for i in 1 2 3 4 5; do echo "note$i" > "$D/ext2/f$i.txt"; done
echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > "$D/ext2/eicar.txt"
ok 'waitfor "test ! -e \"$D/ext2/eicar.txt\"" && ls "$HOME/.local/share/mountain/quarantine" | grep -q eicar' "an EICAR named .txt in the next extracted folder is quarantined"
kill "$d" 2>/dev/null; wait "$d" 2>/dev/null
((rc)) && { echo "--- watcher log"; cat "$log"; }
rm -rf "$T"; exit $rc
