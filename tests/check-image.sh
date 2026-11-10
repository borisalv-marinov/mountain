#!/usr/bin/env bash
set -euo pipefail

# Runs inside the built image. Usage: check-image.sh <phase>

fail() {
  echo "FAIL: $*"
  exit 1
}

assert_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "command not found: $1"
}

assert_file() {
  [[ -f "$1" ]] || fail "file missing: $1"
}

assert_grep() {
  grep -q -- "$1" "$2" 2>/dev/null || fail "pattern '$1' not found in $2"
}

assert_no_rpm() {
  if rpm -q "$1" >/dev/null 2>&1; then
    fail "package still installed: $1"
  fi
}

check_phase0() {
  assert_file /usr/share/mountain/config
}

check_phase1() {
  assert_no_rpm micro
  assert_no_rpm starship
  assert_cmd flatpak # Bazzite ships Firefox as a Flatpak installed at first boot, so it is not in the image
}

check_phase2() {
  # list path per blue-build/modules default-flatpaks v1 script
  for id in dev.vencord.Vesktop com.discordapp.Discord; do
    assert_grep "$id" /usr/share/bluebuild/default-flatpaks/system/install
  done
  assert_cmd pw-cli
}

PHASE=${1:-0}
for p in $(seq 0 "$PHASE"); do
  fn="check_phase$p"
  if declare -F "$fn" >/dev/null; then
    "$fn"
  fi
done
echo "PASS: phase $PHASE"
