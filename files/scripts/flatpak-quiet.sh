#!/usr/bin/env bash
# v7: no "Automatic Flatpak Installation Service" toasts. BlueBuild default-flatpaks notify-sends with that --app-name when a config has notify: true;
# a plasmanotifyrc rule did not catch it, so turn notify off in the generated config (this also covers a user-scope entry with 0 Flatpaks that comes from the base image).
# The services still run and install the apps.
set -euo pipefail
f=/usr/share/bluebuild/default-flatpaks/configuration.yaml
[[ -f $f ]] || { echo "flatpak-quiet: missing $f"; exit 1; }
grep -q '^ *notify: true' $f || { echo "flatpak-quiet: no notify: true in $f (module changed?)"; exit 1; }
sed -i 's/^\( *\)notify: true/\1notify: false/' $f
! grep -q 'notify: true' $f
