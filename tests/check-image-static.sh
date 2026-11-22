#!/usr/bin/env bash
# Image rules that need no built image: the repo's files/system tree is checked as if it were / (MOUNTAIN_ROOT).
# Runs in the lint job (a minute, on a plain Ubuntu runner) so a rule failure costs a minute, not the 25-minute image build
# (v7.4: four builds were lost to rules that only ran inside the image), and in tests/prepush.sh.
#   1. every image-check phase that is repo-aware (41 and later: they read $MOUNTAIN_ROOT);
#   2. repo-side versions of in-image rules the older phases only check with absolute paths;
#   3. every Mountain unit named in the recipe exists, every timer has its service.
# shortcut: phases 0-40 read /usr and /etc directly (rpm, systemctl, installed files) and still run only inside the image;
# make a phase repo-aware by prefixing its paths with ${MOUNTAIN_ROOT:-}, then it is picked up here by raising FIRST below.
set -uo pipefail
cd "$(dirname "$0")/.."
export MOUNTAIN_ROOT=files/system
X=$MOUNTAIN_ROOT
FIRST=41
bad=0; fail() { echo "FAIL: $*"; bad=1; }

# 1. repo-aware phases, each in its own shell (fail() exits)
nums=$(grep -oE '^check_phase[0-9]+' tests/check-image.sh | grep -oE '[0-9]+$' | sort -n)
for n in $nums; do
  (( n >= FIRST )) || continue
  ( source <(sed '/^phases=/,$d' tests/check-image.sh | tr -d '\r'); "check_phase$n" ) >/tmp/phase.$$ 2>&1 || { grep -E '^FAIL' /tmp/phase.$$ | head -3; fail "image check phase $n (repo mode)"; }
done
rm -f /tmp/phase.$$

# 2. repo-side rules
# every notify-send call, comments included, carries -a: the toast header names the app (rule of phase 33)
bad_ns=$(grep -rn 'notify-send [^>]' $X/usr/libexec/mountain-* 2>/dev/null | grep -v 'notify-send -a ' || true)
[[ -z $bad_ns ]] || { echo "$bad_ns" | head -3; fail "notify-send without -a (toast header says notify-send)"; }
# kwinrulesrc: [General] count and rules match the rule groups (rule of phase 33)
python3 - <<'PY' || fail "kwinrulesrc: [General] count/rules do not match the rule groups"
import configparser
c = configparser.RawConfigParser(strict=True); c.optionxform = str; c.read("files/system/etc/xdg/kwinrulesrc", encoding="utf-8")
r = c["General"]["rules"].split(",")
assert int(c["General"]["count"]) == len(r) and all(c.has_section(x) for x in r), r
PY
# shell scripts parse
for f in $X/usr/libexec/* $X/usr/bin/* tests/*.sh; do
  [[ -f $f ]] && head -c 80 "$f" | grep -q '^#!.*\(bash\|sh\)' && { bash -n "$f" 2>/dev/null || fail "shell syntax: $f"; }
done
# desktop entries validate (when the tool exists on this machine)
if command -v desktop-file-validate >/dev/null; then
  for f in $X/usr/share/applications/org.mountain.*.desktop; do desktop-file-validate "$f" >/dev/null 2>&1 || fail "desktop file: $f"; done
fi

# 3. units named in the recipe exist; every timer has its service
for u in $(grep -ohE 'mountain-[a-z0-9-]+\.(service|timer|path)' recipes/*.yml | sort -u); do
  [[ -e $X/usr/lib/systemd/system/$u || -e $X/usr/lib/systemd/user/$u ]] || fail "recipe names $u but no unit file exists"
done
for t in $X/usr/lib/systemd/system/*.timer; do
  [[ -f ${t%.timer}.service ]] || fail "timer without a service: ${t##*/}"
done

(( bad )) && { echo "STATIC IMAGE RULES FAILED"; exit 1; }
echo "static image rules ok"
