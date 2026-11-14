#!/usr/bin/env bash
# Tests mountain-snapshot's keep rule: newest N, plus the newest of each of the last D days.
MOUNTAIN_SNAP_LIB=1 source "$(dirname "$0")/../files/system/usr/libexec/mountain-snapshot"
rc=0
ok() { if eval "$1"; then echo "ok: $2"; else echo "FAIL: $2"; rc=1; fi; }
# 30 hourly snapshots on 2026-11-12 (00..23 + 6 more on the 11th), then one a day back to 2026-11-01
names=$( { for h in $(seq -w 0 23); do echo "2026-11-12_${h}00"; done; for h in 18 19 20 21 22 23; do echo "2026-11-11_${h}00"; done
           for d in $(seq -w 1 10); do echo "2026-11-${d}_1200"; done; } | sort -r)
del=$(prune_list 24 7 <<<"$names")
ok '! grep -q "2026-11-12" <<<"$del"' "today's 24 kept"
ok '! grep -qx "2026-11-11_2300" <<<"$del"' "newest of yesterday kept"
ok 'grep -qx "2026-11-11_1800" <<<"$del"' "older ones of yesterday removed"
ok '! grep -qx "2026-11-06_1200" <<<"$del"' "7th day kept"
ok 'grep -qx "2026-11-05_1200" <<<"$del" && grep -qx "2026-11-01_1200" <<<"$del"' "8th day and older removed"
low=$(prune_list 3 3 <<<"$names")
ok '! grep -qx "2026-11-11_2300" <<<"$low" && ! grep -qx "2026-11-10_1200" <<<"$low"' "low disk: yesterday and the day before stay"
ok 'grep -qx "2026-11-09_1200" <<<"$low"' "low disk: 4th day and older freed"
ok '[[ $(wc -l <<<"$low") == $(( $(wc -l <<<"$names") - 3 - 2 )) ]]' "low disk: newest 3 (all today) + 2 older dailies kept"
ok 'grep -q "recent=3; days=3" "$(dirname "$0")/../files/system/usr/libexec/mountain-snapshot"' "low disk keeps 3 dailies"
ok '[[ -z $(prune_list 24 7 <<<"") ]]' "nothing to do"
# a program starting the unit again and again (snapshots by hand) cannot push out today's hourly ones
M=$(mktemp); spam=$(for m in $(seq -w 1 30); do echo "2026-11-12_23$m"; done); printf '%s\n' "$spam" > "$M"
del=$(printf '%s\n%s\n' "$names" "$spam" | to_prune 24 7 "$M")
ok '! grep -q "2026-11-12_[0-9][0-9]00" <<<"$del" && ! grep -qx "2026-11-11_2300" <<<"$del"' "hand-made snapshots never take the hourly slots"
ok '[[ $(grep -cxFf "$M" <<<"$del") == 27 ]] && ! grep -qx "2026-11-12_2330" <<<"$del"' "only the newest 3 hand-made snapshots are kept"
: > "$M"; ok '[[ $(to_prune 24 7 "$M" <<<"$names") == "$(prune_list 24 7 <<<"$names")" ]]' "no hand-made snapshots: the usual rule"
ok '[[ -z $(to_prune 24 7 "$M" </dev/null) ]]' "no snapshots: nothing to delete"
rm -f "$M"
exit $rc
