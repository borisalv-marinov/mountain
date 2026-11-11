#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Lines like "  - org.mozilla.firefox": reverse-DNS app IDs with at least two dots.
# Copr entries such as "atim/starship" contain a slash and are skipped.
IDS=$(grep -hE '^\s*-\s+[a-zA-Z0-9_-]+\.[a-zA-Z0-9_.-]+\s*(#.*)?$' recipes/*.yml \
  | sed -E 's/^\s*-\s+//; s/\s*(#.*)?$//' \
  | grep -E '^[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+){2,}$' \
  | sort -u || true)

if [[ -z "$IDS" ]]; then
  echo "WARNING: no Flathub IDs found in recipes/*.yml"
  exit 0
fi

failed=0
while read -r id; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "https://flathub.org/api/v2/appstream/$id" || true)
  if [[ "$code" != "200" ]]; then
    echo "FAIL: Flathub ID not found (HTTP $code): $id"
    failed=1
  else
    echo "OK: $id"
  fi
done <<< "$IDS"
exit $failed
