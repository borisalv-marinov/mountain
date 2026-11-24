#!/bin/bash
# The sign-in screen must really be drawn, not only "started": a display manager that is active but whose greeter or
# compositor never ran (broken GPU/Qt stack) must roll the update back. Waits at most 150 s so a slow healthy boot passes.
# Passes on a greeter, a compositor (kwin_wayland: greeter or autologin session) or a graphical user session.
for _ in $(seq 75); do
  if systemctl is-active --quiet display-manager.service \
     && { pgrep -f 'greeter|kwin_wayland' >/dev/null || loginctl list-sessions --no-legend 2>/dev/null | grep -q seat; }; then
    exit 0
  fi
  sleep 2
done
echo "mountain: the sign-in screen service is up but no greeter or compositor is running"; exit 1
