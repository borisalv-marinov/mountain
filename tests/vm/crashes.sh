#!/bin/bash
# Programs that crashed this boot, as "count path". Default: all but the known open ones; "known": only those.
# Known open: kioworker (register B1, KDE's own) and Edge's exit-time abort in its Flatpak sandbox helper
# (zypak frees an sd-event loop during exit(): "Assertion 's->floating' failed ... event_free()", vm-test 45504427559).
# Any other Edge crash still counts.
mode=${1:-other}
coredumpctl list --no-legend --no-pager 2>/dev/null |
  awk '{p = ""; for (i = 6; i <= NF; i++) if (substr($i, 1, 1) == "/") p = $i; if (p != "") print $5, p}' |
  while read -r pid exe; do
    known=0
    [ "$exe" = /usr/libexec/kf6/kioworker ] && known=1
    [ "$exe" = /app/extra/msedge ] && journalctl -b --no-pager -o cat _PID="$pid" 2>/dev/null |
      grep -qF "Assertion 's->floating' failed at src/libsystemd/sd-event/sd-event.c" && known=1
    { [ "$mode" = known ] && [ $known = 1 ]; } || { [ "$mode" != known ] && [ $known = 0 ]; } && echo "$exe"
  done | sort | uniq -c | awk '{print $1, $2}' | paste -sd' '
