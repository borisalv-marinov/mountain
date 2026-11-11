#!/usr/bin/env bash
set -euo pipefail
trap 'echo "FAIL: line $LINENO: $BASH_COMMAND"' ERR

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

check_phase7() {
  local s=/usr/lib/sysctl.d/90-mountain.conf t=/usr/lib/systemd/system/uupd.timer.d/mountain.conf
  assert_grep '^net.core.default_qdisc = fq$' "$s"
  assert_grep '^net.ipv4.tcp_congestion_control = bbr$' "$s"
  # uupd.timer is Bazzite's update timer (ublue-os/uupd); no services are disabled on purpose
  assert_grep '^OnCalendar=weekly$' "$t"
  assert_grep '^Persistent=true$' "$t"
}

check_phase9() {
  local s=/usr/libexec/mountain-gpu-check d out want
  assert_file "$s"
  [[ -x $s ]] || fail "not executable: $s"
  d=$(mktemp -d)
  printf '#!/bin/sh
echo "01:00.0 VGA compatible controller [0300]: NVIDIA Corporation [10de:2484]"
' > "$d/lspci"
  chmod +x "$d/lspci"
  export MOUNTAIN_STATE_DIR=$d/state
  mkdir -p "$MOUNTAIN_STATE_DIR"
  if command -v nvidia-smi >/dev/null 2>&1; then
    # NVIDIA image + NVIDIA GPU: already matching
    out=$(PATH="$d:$PATH" "$s" --dry-run); [[ $out == "nothing to do" ]] || fail "expected 'nothing to do', got: $out"
  else
    want=ghcr.io/borisalv-marinov/mountain-nvidia:latest
    out=$(PATH="$d:$PATH" "$s" --dry-run); [[ $out == "would switch to $want" ]] || fail "expected switch to $want, got: $out"
    echo "$want" > "$MOUNTAIN_STATE_DIR/gpu-switched"
    out=$(PATH="$d:$PATH" "$s" --dry-run); [[ $out == "already switched" ]] || fail "expected 'already switched', got: $out"
  fi
  unset MOUNTAIN_STATE_DIR
  rm -rf "$d"
}

check_phase10() {
  local l=/usr/share/plasma/look-and-feel/org.mountain.desktop p=/usr/share/kde-settings/kde-profile/default/xdg
  # shellcheck disable=SC1091
  source /usr/share/mountain/config
  grep -q "^PRETTY_NAME=\"${MOUNTAIN_NAME} " /usr/lib/os-release || fail "PRETTY_NAME does not start with $MOUNTAIN_NAME"
  assert_grep panel "$l/contents/layouts/org.kde.plasma.desktop-layout.js"
  assert_grep "^LookAndFeelPackage=org.mountain.desktop$" /etc/xdg/kdeglobals
  assert_grep "^blurEnabled=true$" /etc/xdg/kwinrc
  assert_file /usr/share/mountain/wallpaper.svg
  assert_grep "\"Name\": \"${MOUNTAIN_NAME}\"" "$l/metadata.json"
  # Fedora's profile dir wins over /etc/xdg, so it must not set these keys
  if grep -qsE '^(LookAndFeelPackage|blurEnabled)=' "$p/kdeglobals" "$p/kwinrc"; then fail "kde-profile overrides our defaults"; fi
  if grep -rl "Mountain" /usr/share/applications /etc/xdg | grep -q .; then fail "hard-coded name in applications or /etc/xdg"; fi
}

check_phase11() {
  local k=/usr/share/Kvantum/GlassDark n=0 f
  assert_cmd kvantummanager
  assert_file "$k/GlassDark.kvconfig"
  assert_file "$k/GlassDark.svg"
  assert_grep '^translucent_windows=true$' "$k/GlassDark.kvconfig"
  assert_grep '^theme=GlassDark$' /etc/xdg/Kvantum/kvantum.kvconfig
  assert_grep '^widgetStyle=kvantum$' /etc/xdg/kdeglobals
  assert_grep '^ButtonsOnRight=IAX$' /etc/xdg/kwinrc
  assert_grep '^blurEnabled=true$' /etc/xdg/kwinrc
  while IFS= read -r f; do
    [[ -x $f ]] || fail "not executable: $f"
    grep -qE '^(Exec|URL)=' "$f" || fail "no Exec/URL: $f"
    n=$((n+1))
  done < <(find /etc/skel/Desktop -name '*.desktop')
  (( n >= 9 )) || fail "only $n desktop icons in /etc/skel/Desktop"
}

check_phase12() {
  assert_file /usr/share/mountain/wallpaper.png
  assert_grep '^Image=file:///usr/share/mountain/wallpaper.png$' /usr/lib/plasmalogin/defaults.conf
  [[ ! -e /etc/skel/.config/autostart/bazzite-portal.desktop ]] || fail "welcome portal still autostarts"
  assert_grep '^mountain$' /etc/hostname
  assert_file /etc/skel/Projects/hello.py
}

check_phase13() {
  local f
  for f in org.kde.kdeconnect.daemon geoclue-demo-agent org.kde.kunifiedpush-distributor org.gnome.SettingsDaemon.DiskUtilityNotify; do
    assert_grep '^Hidden=true$' "/etc/xdg/autostart/$f.desktop"
  done
  assert_grep '^Indexing-Enabled=false$' /etc/xdg/baloofilerc
  assert_grep '^InputMethod=$' /etc/xdg/kwinrc
  [[ -x /usr/libexec/mountain-lite-mode ]] || fail "mountain-lite-mode not executable"
  assert_file /etc/xdg/autostart/mountain-lite-mode.desktop
  assert_cmd eglinfo
}

check_phase14() {
  command -v xmllint >/dev/null 2>&1 || fail "xmllint missing (add libxml2 to recipes/common.yml)"
  local f i d
  for f in /usr/share/icons/hicolor/scalable/apps/mountain-{logo,boosteroid}.svg /usr/share/icons/hicolor/scalable/places/mountain-folder-{cloudgaming,games,launchers,browsers,coding,ai,office,chat}.svg; do
    assert_file "$f"
    xmllint --noout "$f" || fail "invalid svg: $f"
  done
  while IFS= read -r f; do
    i=$(sed -n '/^Icon=/{s/^Icon=//p;q}' "$f")
    [[ -n "$i" ]] || continue
    case "$i" in
      /*) [[ -f "$i" ]] || fail "$f: icon missing: $i" ;;
      com.*|org.*|dev.*|io.*) ;; # flatpak ids arrive at first boot
      *) d=$(find /usr/share/icons /var/lib/flatpak/exports/share/icons \( -name "$i.svg" -o -name "$i.png" \) -xtype f -print -quit 2>/dev/null || true)
         [[ -n "$d" ]] || fail "$f: icon not found: $i" ;;
    esac
  done < <(find /usr/share/applications -name "mountain-*.desktop" -o -name "*code*.desktop"; find /etc/skel/Desktop -name '*.desktop')
}

check_phase15() {
  local f d n
  for f in /etc/xdg/menus/applications-merged/mountain.menu /etc/xdg/menus/plasma-applications-merged/mountain.menu; do
    xmllint --noout "$f" || fail "invalid $f"
  done
  for n in cloudgaming games launchers browsers coding ai office chat; do assert_file /usr/share/desktop-directories/mountain-$n.directory; done
  for d in "Cloud Gaming" Games "Game Launchers" Browsers Coding AI Office Chat; do
    [[ -n "$(find "/etc/skel/Desktop/$d" -name '*.desktop' 2>/dev/null)" ]] || fail "desktop folder empty/missing: $d"
    assert_file "/etc/skel/Desktop/$d/.directory"
  done
  while IFS= read -r f; do [[ -x "$f" ]] || fail "not executable: $f"; done < <(find /etc/skel/Desktop -name '*.desktop')
}

check_phase16() {
  assert_cmd node; assert_cmd npm; assert_cmd konsole
  assert_file /usr/libexec/mountain-ai
  [[ -x /usr/libexec/mountain-ai ]] || fail "mountain-ai not executable"
  local n
  for n in claude codex gemini copilot; do assert_file /usr/share/applications/mountain-ai-$n.desktop; done
}

# Plasma 6 ships many applets as compiled plugins, not plasmoid dirs.
applet_exists() {
  [[ -e /usr/share/plasma/plasmoids/$1 ]] || compgen -G "/usr/lib*/qt6/plugins/plasma/applets/$1.so" >/dev/null
}

check_phase17() {
  local L=/usr/share/plasma/look-and-feel/org.mountain.desktop/contents/layouts/org.kde.plasma.desktop-layout.js id
  assert_file "$L"
  for id in kickoff icontasks systemtray digitalclock; do
    applet_exists "org.kde.plasma.$id" || fail "plasmoid missing: $id"
  done
  # optional applets are guarded by knownWidgetTypes in the layout: report, do not fail
  for id in $(grep -o 'opt([A-Za-z_]*, *"[^"]*"' "$L" | grep -o '"[^"]*"' | tr -d '"' | sort -u); do
    applet_exists "$id" || echo "NOTE: optional applet not installed: $id"
  done
  assert_grep 'mountain-logo' "$L"
  assert_grep 'ButtonsOnRight=IAX' /etc/xdg/kwinrc
  assert_grep 'ActiveView=systemsettings_sidebar_mode' /etc/xdg/systemsettingsrc
  assert_grep 'SingleClick=false' /etc/xdg/kdeglobals
}

check_phase18() {
  assert_file /usr/share/icons/We10X-dark/index.theme
}

PHASE=${1:-0}
for p in $(seq 0 "$PHASE"); do
  fn="check_phase$p"
  if declare -F "$fn" >/dev/null; then
    "$fn"
  fi
done
echo "PASS: phase $PHASE"
