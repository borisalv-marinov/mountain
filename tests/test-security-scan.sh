#!/usr/bin/env bash
# Tests mountain-security's scan: what clamscan reports FOUND is moved to quarantine, LOCKED/LIMIT files stay put.
# clamscan is a stand-in that exits 1 on a find like the real one (that exit once made every re-check say "not found").
set -u
S=$(cd "$(dirname "$0")/../files/system/usr/libexec" && pwd)/mountain-security
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; failn=0
ok() { if eval "$1"; then echo "ok: $2"; pass=$((pass + 1)); else echo "FAIL: $2"; failn=$((failn + 1)); fi; }
mkdir -p "$T/bin" "$T/db" "$T/home/scan" "$T/data"; : > "$T/db/main.cvd"
cat > "$T/bin/clamscan" <<'C'
#!/usr/bin/env bash
r=0; for a; do [[ $a == -* ]] && continue; while IFS= read -r f; do
  if grep -q EVIL "$f"; then echo "$f: Evil FOUND"; echo "$f: Evil-2 FOUND"; r=1 # --allmatch: more than one line per file
  elif grep -q LOCKEDZIP "$f"; then echo "$f: Heuristics.Encrypted.Zip FOUND"; r=1; fi
done < <(find "$a" -type f); done; exit $r
C
printf '#!/bin/sh\nshift 2; exec "$@"\n' > "$T/bin/nice"; printf '#!/bin/sh\nshift; exec "$@"\n' > "$T/bin/ionice"
for c in systemd-run nm-online xdg-user-dir notify-send; do printf '#!/bin/sh\nexit 1\n' > "$T/bin/$c"; done
chmod +x "$T/bin"/*
echo EVIL > "$T/home/scan/bad.com"; echo LOCKEDZIP > "$T/home/scan/locked.zip"; echo fine > "$T/home/scan/ok.txt"
O=$(HOME=$T/home XDG_DATA_HOME=$T/data MOUNTAIN_CLAMAV_DB=$T/db PATH=$T/bin:$PATH bash "$S" scan --no-update "$T/home/scan" 2>&1)
Q=$T/data/mountain/quarantine
ok '[[ ! -e $T/home/scan/bad.com && -e $Q/bad.com ]]' "a FOUND file is moved to quarantine (clamscan exits 1 on a find)"
ok '[[ -e $T/home/scan/locked.zip && ! -e $Q/locked.zip ]]' "a password-protected archive stays where it is"
ok '[[ -e $T/home/scan/ok.txt ]]' "a clean file stays"
ok 'grep -q "^av_result=found$" <<<"$O"' "the result says found"
ok '! grep -q "could not quarantine" <<<"$O"' "no quarantine error"
echo "$pass passed, $failn failed"; ((failn == 0))
