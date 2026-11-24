#!/usr/bin/env bash
# Static test of the daily Flatpak update units (system and user) and of the virus-definitions timer delay.
D=$(dirname "$0")/../files/system/usr/lib/systemd rc=0
ok() { if eval "$1"; then echo "ok: $2"; else echo "FAIL: $2"; rc=1; fi; }
for s in system user; do
  v=$D/$s/mountain-app-updates.service t=$D/$s/mountain-app-updates.timer
  ok "grep -qx 'ExecStart=/usr/bin/flatpak update --$s --noninteractive -y' $v" "$s: updates only its own scope, no prompts"
  ok "grep -q '^ExecCondition=.*nm-online.*GENERAL.METERED' $v" "$s: skipped offline and on a metered connection"
  ok "grep -qx 'Nice=19' $v && grep -qx 'IOSchedulingClass=idle' $v && grep -qx 'CPUSchedulingPolicy=idle' $v" "$s: lowest CPU and disk priority"
  ok "grep -qx 'Type=oneshot' $v" "$s: one-shot service"
  ok "grep -qx 'OnCalendar=daily' $t && grep -qx 'Persistent=true' $t && grep -q '^RandomizedDelaySec=' $t" "$s: daily timer, catches up after being off, spread out"
  ok "grep -qx 'WantedBy=timers.target' $t" "$s: timer installable"
done
ok "grep -qx 'RandomizedDelaySec=20s' $D/system/mountain-virus-definitions-auto.timer && grep -qx 'OnBootSec=1min' $D/system/mountain-virus-definitions-auto.timer && grep -qx 'OnUnitActiveSec=1d' $D/system/mountain-virus-definitions-auto.timer" "definitions timer: first download within about 1.5 min of boot, then daily"
exit $rc
