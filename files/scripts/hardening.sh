#!/usr/bin/env bash
# Switch the default firewall zone from FedoraWorkstation (opens all ports 1025-65535) to the closed "mountain" zone.
set -euo pipefail
f=/etc/firewalld/firewalld.conf
sed -i 's/^DefaultZone=.*/DefaultZone=mountain/' "$f"
grep -q '^DefaultZone=mountain$' "$f"
