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
ok '[[ $(prune_list 3 0 <<<"$names" | wc -l) == $(( $(wc -l <<<"$names") - 3 )) ]]' "low disk: only 3 kept"
ok '[[ -z $(prune_list 24 7 <<<"") ]]' "nothing to do"
exit $rc
