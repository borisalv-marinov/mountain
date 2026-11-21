#!/usr/bin/env bash
# Run before EVERY push (v7.4: three builds in a row were lost to mistakes this would have caught).
#   bash tests/prepush.sh
# What it runs on a dev PC without Linux: QML syntax, shell syntax of every changed script, the image-check phases in repo mode,
# the workflow YAML, the Bulgarian catalog, the Try Mountain keysym test, and a refusal to push while a build is running
# (a push cancels the build in progress).
# shortcut: tests/test-protect-daemon.sh needs inotifywait (Linux); it is NOT run here. After editing mountain-protect or its notify calls,
# read that test's fake notify-send/ClamAV expectations by hand, or run it on a Linux box.
set -uo pipefail
cd "$(dirname "$0")/.."
bad=0; fail() { echo "FAIL: $*"; bad=1; }

bash tests/check-qml-syntax.sh >/dev/null 2>&1 || { bash tests/check-qml-syntax.sh | tail -3; fail "QML syntax"; }

while read -r f; do
  [[ -f $f ]] || continue
  head -c 80 "$f" | grep -q '^#!.*\(bash\|sh\)' && { bash -n "$f" 2>&1 || fail "shell syntax: $f"; }
done < <({ git diff --name-only origin/main; git diff --name-only; git ls-files --others --exclude-standard; } | sort -u | grep -v '\.\(md\|png\|mo\)$')

python3 -c "import yaml,sys; [yaml.safe_load(open(f,encoding='utf-8')) for f in sys.argv[1:]]" .github/workflows/*.yml recipes/*.yml 2>&1 | tail -2
[[ ${PIPESTATUS[0]} == 0 ]] || fail "YAML does not parse"

# the lint job's unit tests that need no Linux-only tool (Git Bash is enough); test-protect.sh is the one that failed build 44839387969
for t in test-protect test-security-scan test-security-conn test-app-permissions test-i18n; do
  [[ -f tests/$t.sh ]] || continue
  r=$(timeout 500 bash tests/$t.sh 2>&1); echo "$r" | grep -qE "^FAIL|^not ok|[1-9][0-9]* failed" && { echo "$r" | grep -E "^FAIL|^not ok|failed" | head -4; fail "tests/$t.sh"; }
done

# image check, repo mode: every phase from 41 on (v7.4 and later). Image-mode paths (no MOUNTAIN_ROOT) are NOT exercised: read each new assert_grep path by eye.
out=$(MOUNTAIN_ROOT=files/system bash -c 'source <(sed "/^phases=/,\$d" tests/check-image.sh | tr -d "\r"); for p in $(declare -F | sed -n "s/.*check_phase\(4[1-9]\|[5-9][0-9]\)$/check_phase\1/p"); do $p || echo "phase failed: $p"; done' 2>&1 | grep -E "FAIL|phase failed" | head -5)
[[ -z $out ]] || { echo "$out"; fail "image check (repo mode)"; }
# a repo path in an assert that also runs inside the image (recipes/, tests/, files/) is the bug behind build 44839752010
grep -nE "assert_(grep|file)[^#]*[ '](recipes|tests|files)/" tests/check-image.sh | grep -v 'X/\|\$X\|-n \$X\|MOUNTAIN_ROOT' | head -5 | sed 's/^/CHECK BY EYE (repo path in an assert): /'

python3 tools/po2mo.py >/dev/null 2>&1; git diff --quiet -- '*.mo' || fail "a .mo is out of date with its .po: run python3 tools/po2mo.py and commit the .mo"
node try/keysym.test.mjs >/dev/null 2>&1 || fail "try/keysym.test.mjs"

if command -v gh >/dev/null; then
  n=$(gh run list --workflow bluebuild --branch "$(git branch --show-current)" --status in_progress --json databaseId -q 'length' 2>/dev/null)
  q=$(gh run list --workflow bluebuild --branch "$(git branch --show-current)" --status queued --json databaseId -q 'length' 2>/dev/null)
  (( ${n:-0} + ${q:-0} == 0 )) || fail "a build of this branch is running or queued: a push now would cancel it. Wait for it, or accept that it is lost."
fi
(( bad )) && { echo "NOT READY TO PUSH"; exit 1; }
echo "ready to push (Protection unit test not run here: see the shortcut note)"
