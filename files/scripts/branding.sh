#!/usr/bin/env bash
# Sets only PRETTY_NAME; ID/NAME stay Bazzite's because its tools read them.
set -euo pipefail
source /usr/share/mountain/config
sed -i "s|^PRETTY_NAME=.*|PRETTY_NAME=\"${MOUNTAIN_NAME} (based on Bazzite)\"|" /usr/lib/os-release
grep -q "^PRETTY_NAME=\"${MOUNTAIN_NAME} " /usr/lib/os-release
