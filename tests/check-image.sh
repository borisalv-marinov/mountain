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
  # path per blue-build/modules default-flatpaks v2 (default-flatpaks.nu, configPath)
  for id in dev.vencord.Vesktop com.discordapp.Discord; do
    assert_grep "$id" /usr/share/bluebuild/default-flatpaks/configuration.yaml
  done
  assert_cmd pw-cli
}

check_phase3() {
  assert_grep com.microsoft.Edge /usr/share/bluebuild/default-flatpaks/configuration.yaml
  assert_cmd desktop-file-validate
  local url f
  for url in geforcenow=https://play.geforcenow.com xboxcloud=https://www.xbox.com/play boosteroid=https://cloud.boosteroid.com; do
    f=/usr/share/applications/mountain-${url%%=*}.desktop
    assert_file "$f"
    assert_grep "^Exec=flatpak run com.microsoft.Edge --app=${url#*=}\$" "$f"
    desktop-file-validate "$f" || fail "invalid desktop file: $f"
  done
}

check_phase4() {
  local c
  for c in code python3 git pip3; do assert_cmd "$c"; done
  python3 -c 'import sys; assert sys.version_info >= (3,12)' || fail "python3 older than 3.12"
  assert_file /etc/skel/Projects/.keep
}

check_phase5() {
  assert_grep org.onlyoffice.desktopeditors /usr/share/bluebuild/default-flatpaks/configuration.yaml
}

check_phase6() {
  assert_grep com.heroicgameslauncher.hgl /usr/share/bluebuild/default-flatpaks/configuration.yaml
  # steam is an RPM layered by Bazzite (build_files/bazzite/08-install-steam-lutris.sh).
  # gamemode is removed by that same script, so gamemoderun is deliberately not checked.
  assert_cmd steam
}

PHASE=${1:-0}
for p in $(seq 0 "$PHASE"); do
  fn="check_phase$p"
  if declare -F "$fn" >/dev/null; then
    "$fn"
  fi
done
echo "PASS: phase $PHASE"
