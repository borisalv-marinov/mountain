#!/usr/bin/env bash
set -Eeuo pipefail # -E: the FAIL line trap also fires inside the phase functions
trap 'echo "FAIL: line $LINENO: $BASH_COMMAND" >&2' ERR # stderr: never captured into a $(...) list

# Runs inside the built image (also as the last recipe module, so a failure stops the push). Runs every check_phaseN.

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
    # v4: launched through mountain-webapp (own window class + profile); still Edge with the same URL
    assert_grep "^Exec=/usr/libexec/mountain-webapp ${url%%=*} ${url#*=}\$" "$f"
    MOUNTAIN_WEBAPP_DRYRUN=1 /usr/libexec/mountain-webapp "${url%%=*}" "${url#*=}" | grep -q -- "^flatpak run com.microsoft.Edge --class=mountain-${url%%=*} .*--app=${url#*=}\$" || fail "mountain-webapp does not open ${url#*=} in Edge"
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
  local s=/usr/lib/sysctl.d/90-mountain.conf
  assert_grep '^net.core.default_qdisc = fq$' "$s"
  assert_grep '^net.ipv4.tcp_congestion_control = bbr$' "$s"
  # uupd.timer (Bazzite's updater) is disabled in the recipe: no background updates, so its weekly drop-in is gone
  [[ ! -e /usr/lib/systemd/system/uupd.timer.d/mountain.conf ]] || fail "dead uupd drop-in is back"
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
  # detect only at boot: the switch runs only after a click (--switch, from the sign-in notification), never waits for the network
  # every bootc switch call sits in the --switch) branch, and there is one
  awk '/^[[:space:]]*--switch\)/ { b = 1 } /bootc switch/ && !/^[[:space:]]*#/ { if (b) n++; else bad = 1 } b && /;;/ { b = 0 } END { exit bad || !n }' "$s" || fail "gpu-check switches without a click"
  assert_grep '--notify' /etc/xdg/autostart/mountain-gpu-notify.desktop
  assert_grep '-A switch=Switch' "$s"
  ! grep -q network-online /usr/lib/systemd/system/mountain-gpu-check.service || fail "gpu-check waits for the network"
  ! grep -q '^After=network-online' /usr/lib/systemd/system/mountain-virus-definitions.service || fail "Scan now waits for the network when offline"
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
  assert_grep '^theme=BlackGlass$' /etc/xdg/Kvantum/kvantum.kvconfig # v5: BlackGlass replaced GlassDark as the default
  assert_grep '^widgetStyle=kvantum$' /etc/xdg/kdeglobals
  assert_grep '^ButtonsOnRight=IAX$' /etc/xdg/kwinrc
  assert_grep '^blurEnabled=true$' /etc/xdg/kwinrc
  while IFS= read -r f; do
    [[ -x $f ]] || fail "not executable: $f"
    grep -qE '^(Exec|URL)=' "$f" || fail "no Exec/URL: $f"
    n=$((n+1))
  done < <(find /etc/skel/Desktop -type f ! -name .directory)
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
  done < <(find /usr/share/applications -name "mountain-*.desktop" -o -name "*code*.desktop"; find /etc/skel/Desktop -type f ! -name .directory)
}

check_phase15() {
  local f d n b t
  for f in /etc/xdg/menus/applications-merged/mountain.menu /etc/xdg/menus/plasma-applications-merged/mountain.menu; do
    xmllint --noout "$f" || fail "invalid $f"
  done
  for n in cloudgaming games launchers browsers coding ai office chat; do assert_file /usr/share/desktop-directories/mountain-$n.directory; done
  for d in "Cloud Gaming" Games "Game Launchers" Browsers Coding AI Office Chat; do
    [[ -n "$(find "/etc/skel/Desktop/$d" -type f ! -name .directory 2>/dev/null)" ]] || fail "desktop folder empty/missing: $d"
    assert_file "/etc/skel/Desktop/$d/.directory"
  done
  while IFS= read -r f; do [[ -x "$f" ]] || fail "not executable: $f"; done < <(find /etc/skel/Desktop -type f ! -name .directory)
  # File Explorer shows a folder launcher by its file name: named like the app (Name=). They keep ".desktop": without it
  # shared-mime-info types them text/plain (seen in the build), so a double-click would open a text file, not the app
  while IFS= read -r f; do
    b=${f##*/}; [[ $b == *.desktop ]] || fail "folder launcher without .desktop (opens as text): $f"
    [[ $(sed -n 's/^Name=//p' "$f" | head -1) == "${b%.desktop}" ]] || fail "folder launcher file name is not its Name=: $f"
  done < <(find /etc/skel/Desktop -mindepth 2 -type f ! -name .directory)
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
    applet_exists "$id" && continue
    [[ $id == org.mountain.* || $id == menu.11.enhanced ]] && fail "Mountain's own applet missing: $id" # ours always ship
    echo "NOTE: optional applet not installed: $id"
  done
  assert_grep 'mountain-logo' "$L"
  assert_grep 'ButtonsOnRight=IAX' /etc/xdg/kwinrc
  assert_grep 'ActiveView=systemsettings_sidebar_mode' /etc/xdg/systemsettingsrc
  assert_grep 'SingleClick=false' /etc/xdg/kdeglobals
}

check_phase18() {
  assert_file /usr/share/icons/We10X-dark/index.theme
}

check_phase19() { # Mountain logo everywhere
  local logo=/usr/share/icons/hicolor/scalable/apps/mountain-logo.svg f n=0 k
  assert_grep '^LOGO=mountain-logo$' /usr/lib/os-release
  grep -q '^BOOTLOADER_NAME="Bazzite' /usr/lib/os-release && fail "boot menu still says Bazzite"
  k=/usr/share/kde-settings/kde-profile/default/xdg/kcm-about-distrorc
  assert_grep "^LogoPath=$logo$" "$k"
  [[ ! -e /etc/xdg/kcm-about-distrorc ]] || fail "Bazzite about page config still in /etc/xdg"
  while IFS= read -r f; do
    case $(readlink -f "$f") in "$logo"|/usr/share/icons/breeze*) n=$((n+1)) ;; *) fail "Windows-style icon left: $f" ;; esac
  done < <(find /usr/share/icons/We10X* \( -name 'start-here*' -o -name 'distributor-logo*' -o -name 'applications-all*' \))
  (( n > 0 )) || fail "no We10X logo icons replaced"
  while IFS= read -r f; do [[ $(readlink -f "$f") == "$logo" ]] || fail "Bazzite logo left: $f"; done < <(find /usr/share/icons/hicolor -name 'bazzite-logo*')
  [[ ! -e /usr/share/wallpapers/bazzite ]] || fail "Bazzite wallpapers still shipped"
  assert_file /etc/skel/.config/no-show-user-motd
  grep -aq mountain-logo /usr/share/icons/hicolor/icon-theme.cache || fail "hicolor cache lacks mountain-logo"
  cmp -s /usr/share/mountain/watermark.png /usr/share/plymouth/themes/spinner/watermark.png || fail "plymouth watermark not ours"
  if command -v lsinitrd >/dev/null 2>&1; then
    [[ $(lsinitrd -f usr/share/plymouth/themes/spinner/watermark.png /usr/lib/modules/*/initramfs.img | md5sum) == "$(md5sum < /usr/share/mountain/watermark.png)" ]] || fail "initramfs has the old boot watermark"
  else fail "lsinitrd missing: the initramfs boot watermark can't be checked"; fi
}

check_phase20() { # line-art wallpaper, login and lock screen
  local w=/usr/share/wallpapers/mountain-peaks s d
  python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["KPlugin"]["Id"]=="mountain-peaks"' "$w/metadata.json" || fail "bad wallpaper metadata"
  for d in images images_dark; do for s in 1920x1080 2560x1440 3840x2160; do
    assert_file "$w/contents/$d/$s.png"
    file "$w/contents/$d/$s.png" | grep -q "${s%x*} x ${s#*x}" || fail "wrong size: $d/$s.png"
  done; done
  assert_file /usr/share/mountain/wallpaper-light.svg
  # v5: Mountain Silk became the default (phase 28 checks it the same way); Peaks stays installed as a choice
}

check_phase21() { # Windows-like start menu and names
  local a=/usr/share/applications L=/usr/share/plasma/look-and-feel/org.mountain.desktop/contents/layouts/org.kde.plasma.desktop-layout.js f
  assert_grep '^Name=Settings$' $a/org.mountain.settings.desktop # v5: Windows-style Settings; KDE's app is "All Settings"
  assert_grep '^Name=All Settings$' $a/systemsettings.desktop
  # Start search shows no KDE settings pages, KDE System Settings, Cardwire or firewall-config, and no KDE-ish descriptions
  assert_grep '^NoDisplay=true$' $a/systemsettings.desktop
  ! grep -q krunner_systemsettings /usr/share/plasma/plasmoids/menu.11.enhanced/contents/ui/main.qml || fail "Start search lists KDE settings pages"
  for f in $(grep -lE '^(Name=Cardwire|Exec=firewall-config)' $a/*.desktop 2>/dev/null || true); do assert_grep '^NoDisplay=true$' "$f"; done
  ! grep -qiE '^(GenericName|Comment)=.*(Windows Security style|setup your PC)' $a/org.mountain.security.desktop $a/io.github.ublue_os.yafti_gtk.desktop || fail "Start search descriptions"
  assert_grep '^Name=File Explorer$' $a/org.kde.dolphin.desktop
  assert_grep '^Name=Task Manager$' $a/org.kde.plasma-systemmonitor.desktop
  assert_grep '^Name=Terminal$' $a/org.kde.konsole.desktop
  for f in kvantummanager org.kde.kwalletmanager org.kde.khelpcenter; do
    [[ -f $a/$f.desktop ]] && assert_grep '^NoDisplay=true$' $a/$f.desktop
  done
  for f in /etc/xdg/menus/applications-merged/mountain.menu /etc/xdg/menus/plasma-applications-merged/mountain.menu; do
    assert_grep mountain-accessories.directory "$f"; assert_grep '<Deleted/>' "$f"
  done
  assert_file /usr/share/desktop-directories/mountain-accessories.directory
  assert_grep 'org.mountain.settings.desktop' /usr/share/kde-settings/kde-profile/default/xdg/kicker-extra-favoritesrc
  grep -qE 'appmenu|systemmonitor\.net|windowtitle|code\.desktop' "$L" && fail "layout still has macOS-style bits or a stale VS Code id"
  assert_file $a/com.microsoft.VSCode.desktop
}

check_phase22() { # files open in the right app; File Explorer feel
  local id
  for id in $(sed -n 's/^[^=]*=\([^;]*\);.*/\1/p' /etc/xdg/mimeapps.list | sort -u); do
    case $id in org.onlyoffice.*|org.mozilla.*) assert_grep "${id%.desktop}" /usr/share/bluebuild/default-flatpaks/configuration.yaml ;;
      *) assert_file "/usr/share/applications/$id" ;; esac
  done
  [[ -x /usr/libexec/mountain-user-setup ]] || fail "mountain-user-setup not executable"
  assert_file /usr/share/mountain/user-places.xbel.in
  assert_file /etc/xdg/autostart/mountain-user-setup.desktop
  assert_file /usr/lib/udev/rules.d/90-mountain-hide-system.rules
  assert_grep '^Name=This PC$' /etc/skel/Desktop/files.desktop
  assert_grep '^DoubleClickInterval=500$' /etc/xdg/kdeglobals
  assert_grep '^BrowseThroughArchives=true$' /etc/xdg/dolphinrc
}

check_phase23() { # lean and secure defaults
  [[ $(systemctl is-enabled input-remapper.service 2>/dev/null) == disabled ]] || fail "input-remapper still enabled"
  [[ -L /etc/systemd/user/kunifiedpush-distributor.service && $(readlink /etc/systemd/user/kunifiedpush-distributor.service) == /dev/null ]] || fail "kunifiedpush not masked"
  [[ ! -e /usr/share/dbus-1/services/org.kde.kdeconnect.service ]] || fail "kdeconnect still D-Bus activated"
  assert_grep '^Hidden=true$' /etc/xdg/autostart/input-remapper-autoload.desktop
  [[ $(systemctl is-enabled firewalld 2>/dev/null) == enabled ]] || fail "firewall not enabled"
  local nop
  nop=$(grep -rhsE '^[^#]*NOPASSWD' /etc/sudoers /etc/sudoers.d || true)
  [[ -n $nop ]] && echo "NOTE: NOPASSWD rules: $nop"
  grep -qE 'NOPASSWD: *ALL *$' <<<"$nop" && fail "passwordless sudo for everything in the image"
  assert_grep '^Autolock=true$' /etc/xdg/kscreenlockerrc
  assert_grep '^LockOnResume=true$' /etc/xdg/kscreenlockerrc
  local t
  for t in uupd.timer dnf-makecache.timer rpm-ostree-countme.timer; do # owner: no background updates (one click via "Updates")
    [[ $(systemctl is-enabled $t 2>/dev/null) == disabled ]] || fail "$t still enabled"
  done
  assert_grep '^Name=Updates$' /usr/share/applications/io.github.rfrench3.bazzite-updater.desktop
}

check_phase24() { # owner addendum: identity, File Explorer bar, top bar switch, launchers, dev env, drivers
  local f p
  python3 -c 'import sys,xml.dom.minidom as m; d=m.parse(sys.argv[1]); assert d.documentElement.getAttribute("version")' /etc/skel/.local/share/kxmlgui5/dolphin/dolphinui.rc || fail "bad dolphinui.rc"
  assert_grep 'name="commandBar"' /etc/skel/.local/share/kxmlgui5/dolphin/dolphinui.rc
  [[ -x /usr/libexec/mountain-topbar ]] || fail "mountain-topbar not executable"
  bash -n /usr/libexec/mountain-topbar || fail "mountain-topbar syntax"
  /usr/libexec/mountain-topbar sideways >/dev/null 2>&1 && fail "mountain-topbar accepted a bad argument"
  for f in topbar python node; do desktop-file-validate /usr/share/applications/mountain-$f.desktop || fail "invalid mountain-$f.desktop"; done
  for f in geforcenow xboxcloud boosteroid; do assert_grep "^StartupWMClass=mountain-$f\$" /usr/share/applications/mountain-$f.desktop; done
  assert_grep 'NPM_CONFIG_PREFIX="$HOME/.local"' /etc/profile.d/mountain-dev.sh
  assert_grep '^TitleAlignment=AlignLeft$' /etc/xdg/breezerc
  assert_grep '^AnimationDurationFactor=0.5$' /etc/xdg/kdeglobals
  assert_grep '^Name=App Store$' /usr/share/applications/io.github.kolunmi.Bazaar.desktop
  assert_grep '^Name=Welcome$' /usr/share/applications/io.github.ublue_os.yafti_gtk.desktop
  grep -qE '^(Name|Comment|GenericName)(\[|=).*Bazzite' /usr/share/applications/io.github.{kolunmi.Bazaar,ublue_os.yafti_gtk,rfrench3.bazzite-updater}.desktop && fail "Bazzite name left in a renamed app"
  # v5.1 owner request supersedes the v4 QA ruling: tab bar only with 2+ tabs, full-width status bar (the small one cut "9 folders"); phase 29 asserts both
  grep -q '^AlwaysShowTabBar=true$' /etc/xdg/dolphinrc && fail "tab bar forced on with one tab"
  assert_grep 'KERNEL=="loop' /usr/lib/udev/rules.d/90-mountain-hide-system.rules
  assert_grep 'erofs' /usr/lib/udev/rules.d/90-mountain-hide-system.rules
  for p in ffmpeg mesa-vulkan-drivers mesa-dri-drivers NetworkManager-wifi; do
    rpm -q "$p" >/dev/null 2>&1 || fail "driver/codec package missing: $p"
  done
  # files, not package names (Bazzite renames/forks some packages)
  compgen -G '/usr/libexec/bluetooth/bluetoothd' >/dev/null || command -v bluetoothd >/dev/null || fail "no Bluetooth daemon"
  assert_cmd pw-cli
  for p in amdgpu i915 'iwlwifi-*' 'rtw8*' nvidia; do
    compgen -G "/usr/lib/firmware/$p*" >/dev/null || fail "firmware missing: $p"
  done
}

check_phase25() { # v4: logo, avatar, Windows 11 start menu, VS Code for text/code
  local m=/usr/share/plasma/plasmoids/menu.11.enhanced
  xmllint --noout /usr/share/icons/hicolor/scalable/apps/mountain-logo.svg || fail "logo svg invalid"
  file /etc/skel/.face.icon | grep -q 'PNG image data, 256 x 256' || fail "no 256 px account picture in skel"
  assert_file /usr/share/plasma/avatars/Mountain.png
  python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["KPlugin"]["Id"]=="menu.11.enhanced"' "$m/metadata.json" || fail "start menu plasmoid metadata"
  assert_grep 'menu.11.enhanced' /usr/share/plasma/look-and-feel/org.mountain.desktop/contents/layouts/org.kde.plasma.desktop-layout.js
  assert_grep 'bell.globalShortcut = "Meta+N"' /usr/share/plasma/look-and-feel/org.mountain.desktop/contents/layouts/org.kde.plasma.desktop-layout.js
  assert_grep '<default>mountain-logo</default>' "$m/contents/config/main.xml"
  assert_grep 'org.mountain.settings.desktop' "$m/contents/config/main.xml"
  assert_grep 'i18n("Recommended")' "$m/contents/ui/MenuRepresentation.qml"
  # v6 owner request supersedes v4: .txt opens in Notepad (KWrite) like Windows; code stays in VS Code (phase 30 asserts it)
  assert_grep '^text/x-python=com.microsoft.VSCode.desktop;$' /etc/xdg/mimeapps.list
  [[ -x /usr/libexec/mountain-webapp ]] || fail "mountain-webapp not executable"
  /usr/libexec/mountain-webapp 'bad id' x >/dev/null 2>&1 && fail "mountain-webapp accepted a bad id"
  true
}

check_phase26() { # v4: smoother backend and hardening (docs/OWNER-GUIDE.md lists how to undo each)
  local k=/usr/lib/sysctl.d/60-mountain-hardening.conf s
  assert_grep '^default_sched = "scx_lavd"$' /etc/scx_loader.toml
  [[ $(systemctl is-enabled scx_loader.service 2>/dev/null) == enabled ]] || fail "scx_loader not enabled"
  [[ $(systemctl is-enabled ModemManager.service 2>/dev/null) == disabled ]] || fail "ModemManager still enabled"
  for s in 'kernel.yama.ptrace_scope = 1' 'kernel.kptr_restrict = 2' 'kernel.dmesg_restrict = 1' 'kernel.unprivileged_bpf_disabled = 1' 'net.ipv4.conf.all.accept_redirects = 0' 'fs.suid_dumpable = 0'; do
    assert_grep "^$s\$" "$k"
  done
  grep -qE 'unprivileged_userns_clone|io_uring_disabled|icmp_echo_ignore_all' "$k" && fail "hardening breaks Steam/flatpak/LAN"
  assert_grep 'slab_nomerge' /usr/lib/bootc/kargs.d/10-mountain-hardening.toml
  python3 -c 'import sys,tomllib; assert isinstance(tomllib.load(open(sys.argv[1],"rb"))["kargs"], list)' /usr/lib/bootc/kargs.d/10-mountain-hardening.toml || fail "kargs toml invalid"
  assert_grep '^DefaultZone=mountain$' /etc/firewalld/firewalld.conf
  xmllint --noout /etc/firewalld/zones/mountain.xml || fail "firewall zone invalid"
  grep -q 'port=' /etc/firewalld/zones/mountain.xml && fail "mountain zone opens raw ports"
  assert_grep 'steam-streaming' /etc/firewalld/zones/mountain-home.xml
  ! grep -q 'steam-streaming' /etc/firewalld/zones/mountain.xml || fail "Steam Remote Play open on Public networks"
  assert_grep '^SELINUX=enforcing$' /etc/selinux/config
}

check_phase27() { # v5: login-screen picture, "File Explorer" in title bars
  local d
  for u in mountain-avatars.service mountain-avatars.path; do
    [[ $(systemctl is-enabled $u 2>/dev/null) == enabled ]] || fail "$u not enabled"
  done
  d=$(mktemp -d); mkdir -p "$d/as/users"
  printf 'ana:x:1000:1000::/home/ana:/bin/bash\nbob:x:1001:1001::/home/bob:/bin/bash\nnobody:x:65534:65534::/:/sbin/nologin\n' > "$d/passwd"
  printf '[User]\nIcon=/home/bob/me.png\n' > "$d/as/users/bob"
  MOUNTAIN_AS_ROOT=$d/as MOUNTAIN_PASSWD=$d/passwd /usr/libexec/mountain-avatars || fail "mountain-avatars failed"
  cmp -s "$d/as/icons/ana" /usr/share/plasma/avatars/Mountain.png || fail "ana got no logo picture"
  assert_grep "^Icon=$d/as/icons/ana\$" "$d/as/users/ana"
  assert_grep '^Icon=/home/bob/me.png$' "$d/as/users/bob"
  [[ ! -e $d/as/icons/bob && ! -e $d/as/users/nobody ]] || fail "mountain-avatars replaced a chosen picture or touched a system account"
  rm -rf "$d"
  python3 -c 'import gettext,sys; t=gettext.GNUTranslations(open(sys.argv[1],"rb")); assert "File Explorer" in t._catalog.values()' /usr/share/locale/en@mountain/LC_MESSAGES/dolphin.mo || fail "File Explorer catalog"
  [[ $(env -i LANG=en_US.UTF-8 bash -c '. /etc/xdg/plasma-workspace/env/mountain-names.sh; echo $LANGUAGE') == en@mountain:en_US ]] || fail "names script: US English"
  grep -q dragImageBeingGenerated /usr/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/FolderView.qml || fail "desktop drag fix missing"
  MOUNTAIN_WEBAPP_DRYRUN=1 /usr/libexec/mountain-webapp geforcenow https://play.geforcenow.com | grep -q -- '--class=mountain-geforcenow --ozone-platform=x11' || fail "web apps not in X11 mode (taskbar grouping)"
  [[ $(env -i LANG=de_DE.UTF-8 bash -c '. /etc/xdg/plasma-workspace/env/mountain-names.sh; echo ${LANGUAGE-unset}') == unset ]] || fail "names script changed another language"
  [[ $(env -i sh -c '. /etc/xdg/plasma-workspace/env/mountain-names.sh; echo $LANGUAGE') == en@mountain:en_US ]] || fail "names script: no language set"
}

check_phase28() { # v5 black glass: lock/login greeting, Silk wallpaper, Windows-style taskbar and desktop
  local L=/usr/share/plasma/look-and-feel/org.mountain.desktop/contents/layouts/org.kde.plasma.desktop-layout.js b w s d
  b=$(find /usr/lib64/qt6/qml /usr/lib/qt6/qml -type d -path '*/org/kde/breeze/components' -print -quit)
  assert_grep '"Hello, "' "$b/UserDelegate.qml"
  # Windows-style wrong-password message; the sign-in clock in 12 h US time like the taskbar when the greeter has no locale
  assert_grep 'The password is incorrect. Try again.' "$b/SessionManagementScreen.qml"
  assert_grep 'mtWrongPassword' "$b/SessionManagementScreen.qml"
  assert_grep 'mtLocale' "$b/Clock.qml"
  grep -q 'Qt.formatTime(timeSource.dateTime, Qt.locale()' "$b/Clock.qml" && fail "sign-in clock not patched (24 h with no locale)"
  grep -q '^prefer ' "$b/qmldir" && fail "breeze components still prefer the compiled copy (greeting not used)"
  assert_file /usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/LockScreenUi.qml
  for w in mountain-silk mountain-silk-dark; do
    python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["KPlugin"]["Id"]==sys.argv[2]' "/usr/share/wallpapers/$w/metadata.json" "$w" || fail "bad $w metadata"
    for d in images images_dark; do for s in 1920x1080 2560x1440 3840x2160; do
      file "/usr/share/wallpapers/$w/contents/$d/$s.png" | grep -q "${s%x*} x ${s#*x}" || fail "wrong or missing $w $d/$s.png"
    done; done
  done
  assert_grep 'mountain-silk/' "$L"
  assert_grep '^Image=file:///usr/share/wallpapers/mountain-silk-dark/$' /etc/xdg/kscreenlockerrc
  assert_grep '^State=' /etc/skel/.local/state/dolphinstaterc # File Explorer opens with the Details (Information) pane
  assert_grep 'BelowTime' "$L"
  assert_grep '"arrangement", 1' "$L"
  grep -q 'location = "top"' "$L" && fail "top bar is on by default"
  grep -q 'systemtray' /usr/libexec/mountain-topbar && fail "top bar would add a second tray"
  assert_grep '^URL=trash:/$' "/etc/skel/Desktop/Recycle Bin.desktop"
  # Windows-style Settings and quick settings
  local a id missing=""
  for a in org.mountain.settings org.mountain.quicksettings; do
    python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["KPlugin"]["Id"]==sys.argv[2]' "/usr/share/plasma/plasmoids/$a/metadata.json" "$a" || fail "bad $a metadata"
    assert_file "/usr/share/plasma/plasmoids/$a/contents/ui/main.qml"
  done
  desktop-file-validate /usr/share/applications/org.mountain.settings.desktop || fail "invalid Settings launcher"
  assert_grep 'org.mountain.quicksettings' "$L"
  assert_grep 'org.mountain.settings.desktop' /usr/share/plasma/plasmoids/menu.11.enhanced/contents/config/main.xml
  assert_cmd plasmawindowed
  for id in $(grep -rhoE 'kcm_[A-Za-z0-9_-]+' /usr/share/plasma/plasmoids/org.mountain.settings /usr/share/plasma/plasmoids/org.mountain.quicksettings | sort -u); do
    compgen -G "/usr/lib*/qt6/plugins/plasma/kcms/*/$id.so" >/dev/null || compgen -G "/usr/lib*/qt6/plugins/plasma/kcms/$id.so" >/dev/null \
      || [[ -e /usr/share/applications/$id.desktop ]] || missing="$missing $id"
  done
  [[ -z $missing ]] || fail "Settings pages without a KDE module:$missing"
  for id in kcm_kscreen kcm_pulseaudio kcm_bluetooth kcm_networkmanagement kcm_wallpaper kcm_colors kcm_users kcm_clock kcm_access; do
    [[ " $missing " == *" $id "* ]] && fail "Settings page has no module: $id"
  done
  # black glass
  assert_file /usr/share/Kvantum/BlackGlass/BlackGlass.svg
  assert_grep '^theme=BlackGlass$' /etc/skel/.config/Kvantum/kvantum.kvconfig
  assert_grep '^translucent_windows=false$' /usr/share/Kvantum/BlackGlassSolid/BlackGlassSolid.kvconfig
  python3 -c 'import sys,xml.etree.ElementTree as E; E.parse(sys.argv[1])' /usr/share/Kvantum/BlackGlass/BlackGlass.svg || fail "Kvantum SVG invalid"
  local t=/usr/share/plasma/desktoptheme/mountain-glass f
  python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["KPlugin"]["Id"]=="mountain-glass"' $t/metadata.json || fail "bad Plasma theme metadata"
  for f in widgets/panel-background translucent/widgets/panel-background dialogs/background translucent/dialogs/background widgets/tooltip widgets/tasks; do
    python3 -c 'import sys,xml.etree.ElementTree as E; E.parse(sys.argv[1])' "$t/$f.svg" || fail "Plasma theme SVG invalid: $f"
  done
  assert_file /usr/share/color-schemes/BlackGlass.colors
  assert_file /usr/share/aurorae/themes/BlackGlass/decoration.svg
  assert_grep '^name=mountain-glass$' /etc/xdg/plasmarc
  assert_grep '^ColorScheme=BlackGlass$' /etc/xdg/kdeglobals
  assert_grep '^theme=__aurorae__svg__BlackGlass$' /etc/xdg/kwinrc
  # one palette: base #121212 (glass 0.82 with blur, opaque without), text #FFFFFF/#C5C5C5, disabled >= 4.5:1, accent #0078D4
  for f in /usr/share/color-schemes/BlackGlass.colors $t/colors; do
    assert_grep '^BackgroundNormal=18,18,18$' "$f"
    assert_grep '^ForegroundInactive=197,197,197$' "$f"
    assert_grep '^ContrastAmount=0.45$' "$f"
    grep -q '^BackgroundNormal=0,120,212$' "$f" || fail "selection is not the accent: $f"
    grep -qE '^(Background|Foreground)[A-Za-z]*=(16,18,22|11,12,15|7,8,10|27,29,34|164,169,178)$' "$f" && fail "old blue-black left in $f"
  done
  cmp -s /usr/share/color-schemes/BlackGlass.colors $t/colors || fail "Plasma theme and color scheme differ"
  grep -q 'stop-color="#121212" stop-opacity="0.82"' $t/dialogs/background.svg || fail "start menu/flyout glass is not #121212 at 0.82"
  grep -q 'stop-color="#121212" stop-opacity="0.82"' $t/widgets/panel-background.svg || fail "taskbar glass is not #121212 at 0.82"
  grep -q 'stop-color="#121212" stop-opacity="1"' $t/translucent/dialogs/background.svg || fail "glass-off flyouts are not solid #121212"
  grep -lq '#24272D\|#07080A' $t/dialogs/background.svg $t/widgets/panel-background.svg && fail "grey-to-black gradient left in the Plasma theme"
  assert_grep '^window.color=#121212$' /usr/share/Kvantum/BlackGlass/BlackGlass.kvconfig
  # Terminal uses the same black glass; Settings cards keep a 3:1 edge against the page
  assert_grep '^DefaultProfile=BlackGlass.profile$' /etc/xdg/konsolerc
  assert_grep '^ColorScheme=BlackGlass$' /usr/share/konsole/BlackGlass.profile
  assert_grep '^Color=18,18,18$' /usr/share/konsole/BlackGlass.colorscheme
  python3 - /usr/share/plasma/plasmoids/org.mountain.settings/contents/ui/main.qml <<'PY' || fail "Settings card edge under 3:1 against the page"
import re, sys
s = open(sys.argv[1], encoding='utf-8').read(); hexc = lambda n: re.search(n + r': "#([0-9A-Fa-f]{6})"', s).group(1)
a = float(re.search(r'rim: Qt\.rgba\(1, 1, 1, ([0-9.]+)\)', s).group(1))
lin = lambda c: (c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
L = lambda rgb: 0.2126 * lin(rgb[0]) + 0.7152 * lin(rgb[1]) + 0.0722 * lin(rgb[2])
top = [int(hexc('glassTop')[i:i + 2], 16) / 255 for i in (0, 2, 4)]; page = [int(hexc('pageColor')[i:i + 2], 16) / 255 for i in (0, 2, 4)]
rim = [c + a * (1 - c) for c in top]
r = (L(rim) + 0.05) / (L(page) + 0.05); print('card edge contrast', round(r, 2)); assert r >= 3, r
PY
  assert_grep '^disabled.text.color=#949494$' /usr/share/Kvantum/BlackGlass/BlackGlass.kvconfig
  grep -q '#1B1D22\|#0E0F12\|#07080A' /usr/share/Kvantum/BlackGlass/BlackGlass.svg && fail "Kvantum SVG has old blue-blacks"
  grep -q '#1B1D22\|#24272D\|#101216' /usr/share/aurorae/themes/BlackGlass/decoration.svg && fail "title bar is not the window color"
  assert_grep 'StandardBackground' /usr/share/plasma/plasmoids/menu.11.enhanced/contents/ui/MenuRepresentation.qml
  assert_grep 'maximumLineCount: 2' /usr/share/plasma/plasmoids/menu.11.enhanced/contents/ui/ItemGridDelegate.qml
  MOUNTAIN_RENDERER=llvmpipe HOME=$(mktemp -d) bash -c 'mkdir -p ~/.config/Kvantum; printf "[General]\ntheme=BlackGlass\n" > ~/.config/Kvantum/kvantum.kvconfig; /usr/libexec/mountain-lite-mode >/dev/null; grep -q "^theme=BlackGlassSolid$" ~/.config/Kvantum/kvantum.kvconfig' || fail "lite mode keeps see-through app windows"
  true
}

check_phase29() { # v6 (was v5.1): brightness, sharp solid windows, File Explorer layout, Task Manager, Security, snapshots, hardening
  local q=/usr/share/plasma/plasmoids/org.mountain.quicksettings/contents/ui f n
  assert_grep 'Not available on this display' $q/BrightnessRow.qml
  grep -q 'item.visible' $q/main.qml && fail "brightness row can still disappear"
  # File Explorer: tab bar only with 2+ tabs, item-count-only status bar (v6, see phase 33), sidebar wide enough for "Documents"/"Recycle Bin"/"Previous versions"
  assert_grep '^AlwaysShowTabBar=false$' /etc/xdg/dolphinrc
  assert_grep '^ShowStatusBar=Small$' /etc/xdg/dolphinrc
  python3 -c 'import base64,sys; b=base64.b64decode(open(sys.argv[1]).read().split("State=")[1]); w=int.from_bytes(b[17:21],"big"); assert w>=150, w' /etc/skel/.local/state/dolphinstaterc || fail "File Explorer sidebar too narrow"
  # contrast: solid app windows, glass menus; Windows-like minimize; crisp fonts
  f=/usr/share/Kvantum/BlackGlass/BlackGlass.kvconfig
  assert_grep '^translucent_windows=false$' $f
  assert_grep '^popup_blurring=true$' $f
  assert_grep '^transparent_dolphin_view=false$' $f
  assert_grep '^squashEnabled=true$' /etc/xdg/kwinrc
  assert_grep '^magiclampEnabled=false$' /etc/xdg/kwinrc
  assert_grep '^XftSubPixel=rgb$' /etc/xdg/kdeglobals
  assert_grep '^XftHintStyle=hintslight$' /etc/xdg/kdeglobals
  grep -qsE '^Xft(SubPixel|HintStyle|Antialias)=' /usr/share/kde-settings/kde-profile/default/xdg/kdeglobals && fail "Fedora profile overrides font rendering"
  # Task Manager: Ctrl+Shift+Esc, Windows 11 tabs, Mountain list face and helper, Start right-click entry
  assert_cmd plasma-systemmonitor
  assert_grep '^X-KDE-Shortcuts=Ctrl+Shift+Esc,Ctrl+Esc$' /usr/share/applications/org.kde.plasma-systemmonitor.desktop
  n=0
  for f in $(sed -n 's/^pageOrder=//p' /etc/xdg/systemmonitorrc | tr , ' '); do
    assert_file "/usr/share/plasma-systemmonitor/$f"; n=$((n+1))
  done
  [[ $n == 7 ]] || fail "Task Manager has $n tabs, want 7"
  for n in Processes Performance "App history" "Startup apps" Users Details Services; do
    grep -qx "Title=$n" /usr/share/plasma-systemmonitor/mountain-*.page || fail "Task Manager tab missing: $n"
  done
  f=/usr/share/ksysguard/sensorfaces/org.mountain.taskmanager.list
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["KPlugin"]["Id"]=="org.mountain.taskmanager.list" and d["KPackageStructure"]=="KSysguard/SensorFace"' $f/metadata.json || fail "bad Task Manager face metadata"
  for n in FullRepresentation CompactRepresentation Config; do assert_file $f/contents/ui/$n.qml; done
  for n in $(grep -ho 'chartFace=[a-z.]*' /usr/share/plasma-systemmonitor/mountain-*.page | sort -u | cut -d= -f2); do
    [[ -d /usr/share/ksysguard/sensorfaces/$n ]] || fail "Task Manager page uses a missing face: $n"
  done
  [[ -x /usr/libexec/mountain-taskmanager ]] || fail "mountain-taskmanager not executable"
  # capture first: "| head -1" would end the helper with SIGPIPE, which pipefail reports as a failure
  f=$(/usr/libexec/mountain-taskmanager device || true); [[ $f == $'id\tPart\tModel\n'* ]] || fail "Task Manager device list"
  f=$(/usr/libexec/mountain-taskmanager services || true); [[ $f == $'id\tName'* ]] || fail "Task Manager services list"
  assert_grep 'text: i18n("Task Manager")' /usr/share/plasma/plasmoids/menu.11.enhanced/contents/ui/main.qml
  # Security: on-demand ClamAV only (no daemon, timer or cron), Settings page, narrow polkit rule
  assert_cmd clamscan
  assert_cmd freshclam
  grep -q '^Example' /etc/freshclam.conf && fail "freshclam.conf still has Example"
  for n in clamav-freshclam.service clamd@scan.service clamav-clamonacc.service; do
    [[ $(systemctl is-enabled "$n" 2>/dev/null) == enabled ]] && fail "background scanner enabled: $n"
  done
  compgen -G '/etc/cron.d/*clam*' >/dev/null && fail "ClamAV cron job present"
  for n in mountain-security mountain-snapshot mountain-flatpak-policy mountain-settings-open; do
    [[ -x /usr/libexec/$n ]] || fail "$n not executable"; bash -n /usr/libexec/$n || fail "$n syntax"
  done
  assert_file /usr/share/plasma/plasmoids/org.mountain.settings/contents/ui/SecurityPage.qml
  assert_grep 'SecurityPage.qml' /usr/share/plasma/plasmoids/org.mountain.settings/contents/ui/main.qml
  desktop-file-validate /usr/share/applications/org.mountain.security.desktop || fail "invalid Security launcher"
  assert_grep 'mountain-virus-definitions.service' /usr/share/polkit-1/rules.d/60-mountain.rules
  assert_grep 'ExecStart=/usr/bin/freshclam' /usr/lib/systemd/system/mountain-virus-definitions.service
  [[ $(systemctl is-enabled mountain-virus-definitions.service 2>/dev/null) == enabled ]] && fail "definitions would download in the background"
  # nearly unbreakable: snapshots, Flatpak sandbox, signed updates, SELinux, no passwordless admin
  [[ $(systemctl is-enabled mountain-snapshot.timer) == enabled ]] || fail "snapshot timer off"
  [[ $(systemctl is-enabled mountain-flatpak-policy.service) == enabled ]] || fail "Flatpak policy off"
  assert_grep 'nofilesystem=home' /usr/libexec/mountain-flatpak-policy
  grep -q 'heroic' /usr/libexec/mountain-flatpak-policy && fail "game launcher sandbox tightened (not gaming-safe)"
  assert_file /usr/lib/tmpfiles.d/mountain-snapshots.conf
  python3 -c 'import json,sys; t=json.load(open("/etc/containers/policy.json"))["transports"]["docker"]; r=[v for k,v in t.items() if "borisalv-marinov" in k]; assert r and any(x.get("type")=="sigstoreSigned" for x in r[0]), r' || fail "updates are not signature-checked"
  assert_grep '^SELINUX=enforcing$' /etc/selinux/config
  grep -rhsE '^[^#]*NOPASSWD' /etc/sudoers /etc/sudoers.d | grep -q . && fail "passwordless sudo in the shipped image"
  grep -q 'lockdown=' /usr/lib/bootc/kargs.d/*.toml 2>/dev/null && fail "kernel lockdown forced (breaks unsigned game drivers)"
  true
}

check_phase30() { # v6: looks like Windows 11 in black glass: full start menu, Windows apps and shortcuts, Bulgarian, recovery
  local m=/usr/share/plasma/plasmoids/menu.11.enhanced/contents a=/usr/share/applications L n f
  L=/usr/share/plasma/look-and-feel/org.mountain.desktop/contents/layouts/org.kde.plasma.desktop-layout.js
  python3 - "$m/config/main.xml" <<'PY' || fail "start menu pins"
import sys, xml.etree.ElementTree as E
ns = {'k': 'http://www.kde.org/standards/kcfg/1.0'}
e = {x.get('name'): (x.find('k:default', ns).text or '') for x in E.parse(sys.argv[1]).getroot().iter('{http://www.kde.org/standards/kcfg/1.0}entry')}
pins = e['favoriteApps'].split(',')
assert e['numberRows'] == '3' and len(pins) == 18 and int(e['numberColumns']) * 3 == 18, (e['numberRows'], len(pins))
assert not any('yafti' in p for p in pins), "Welcome pinned"
PY
  assert_grep 'The more you use your device' $m/ui/MenuRepresentation.qml
  for f in org.kde.kwrite.desktop org.kde.kcalc.desktop org.kde.gwenview.desktop org.kde.haruna.desktop org.kde.spectacle.desktop org.kde.plasma-systemmonitor.desktop org.mountain.security.desktop; do
    assert_file $a/$f
  done
  for n in "kcalc:Calculator" "gwenview:Photos" "haruna:Media Player" "kamoso:Camera" "kclock:Clock" "spectacle:Snipping Tool" "kolourpaint:Paint" "krecorder:Sound Recorder" "skanlite:Scanner" "kdeconnect.app:Phone Link" "kwrite:Notepad"; do
    assert_grep "^Name=${n#*:}$" "$a/org.kde.${n%%:*}.desktop"
  done
  assert_grep '^Name=VS Code$' $a/com.microsoft.VSCode.desktop
  assert_grep '^text/plain=org.kde.kwrite.desktop;$' /etc/xdg/mimeapps.list
  assert_grep '^text/x-python=com.microsoft.VSCode.desktop;$' /etc/xdg/mimeapps.list
  # Windows shortcuts
  assert_grep '^X-KDE-Shortcuts=Meta+I$' $a/org.mountain.settings.desktop
  assert_grep '^X-KDE-Shortcuts=Meta+R$' $a/org.mountain.run.desktop
  grep -qs '^X-KDE-Shortcuts=.*Meta+R' $a/org.kde.krunner.desktop /usr/share/kglobalaccel/org.kde.krunner.desktop && fail "Win+R still on KRunner"
  assert_grep $'^_launch=Alt+Space\tAlt+F2\tSearch$' /etc/skel/.config/kglobalshortcutsrc
  assert_grep '^\[services\]\[org.mountain.run.desktop\]$' /etc/skel/.config/kglobalshortcutsrc
  assert_grep '^X-KDE-Shortcuts=Meta+E$' $a/org.kde.dolphin.desktop
  for f in $a/org.kde.spectacle.desktop /usr/share/kglobalaccel/org.kde.spectacle.desktop; do # PrtSc: full screenshot
    [[ ! -e $f ]] || { assert_grep '^X-KDE-Shortcuts=Print$' "$f"; assert_grep '^X-KDE-Shortcuts=$' "$f"
      ! grep -qE '^X-KDE-Shortcuts=(.*,)?Meta\+(R|Shift\+S)(,|$)' "$f" || fail "Spectacle still holds Win+R or Win+Shift+S: $f"; }
  done
  assert_grep $'^Overview=Meta+Tab\tMeta+W,' /etc/skel/.config/kglobalshortcutsrc
  assert_grep '^next activity=none,' /etc/skel/.config/kglobalshortcutsrc
  assert_grep $'^_launch=Ctrl+Shift+Esc\tCtrl+Esc$' /etc/skel/.config/kglobalshortcutsrc
  assert_grep '^\[services\]\[mountain-winx.desktop\]$' /etc/skel/.config/kglobalshortcutsrc
  assert_grep '^toggle_hud=Super_L+g$' /etc/xdg/MangoHud/MangoHud.conf
  assert_grep '^MANGOHUD=1$' /usr/lib/environment.d/60-mountain-mangohud.conf
  assert_grep '^MANGOHUD_CONFIGFILE=/etc/xdg/MangoHud/MangoHud.conf$' /usr/lib/environment.d/60-mountain-mangohud.conf
  assert_grep '^clipboardGroup=PostScreenshotCopyImage$' /etc/xdg/spectaclerc
  # Bulgarian keyboard, Cyrillic fonts
  assert_grep '^LayoutList=us,bg,bg$' /etc/xdg/kxkbrc
  assert_grep '^VariantList=,phonetic,$' /etc/xdg/kxkbrc
  assert_grep '^Options=grp:alt_shift_toggle$' /etc/xdg/kxkbrc
  n=$(fc-list :lang=bg family 2>/dev/null || true); [[ -n $n ]] || fail "no font covers Bulgarian" # captured: grep -q would SIGPIPE fc-list under pipefail
  # Windows 11 taskbar: 48 px, not floating, show-desktop corner
  assert_grep 'panel.height = 48' "$L"
  assert_grep 'panel.floating = false' "$L"
  assert_grep 'org.kde.plasma.showdesktop' "$L"
  # Phone Link starts KDE Connect only when opened; Restore previous versions; Reset this PC
  assert_grep '^Exec=/usr/libexec/mountain-phonelink$' $a/org.kde.kdeconnect.app.desktop
  [[ ! -e /usr/share/dbus-1/services/org.kde.kdeconnect.service ]] || fail "Phone Link daemon D-Bus activated (background drain)"
  assert_grep 'kdeconnect' /etc/firewalld/zones/mountain-home.xml
  ! grep -q 'kdeconnect' /etc/firewalld/zones/mountain.xml || fail "Phone Link open on Public networks"
  assert_grep 'Exec=/usr/libexec/mountain-previous-versions %f' /usr/share/kio/servicemenus/mountain-previous-versions.desktop
  for n in mountain-phonelink mountain-previous-versions; do [[ -x /usr/libexec/$n ]] || fail "$n not executable"; bash -n /usr/libexec/$n || fail "$n syntax"; done
  assert_grep 'reset) reset_pc' /usr/libexec/mountain-security
  for n in kcalc kclock kolourpaint kamoso krecorder skanlite spectacle; do assert_cmd $n; done
  true
}

check_phase31() { # v6 brief: Restart into Windows, full Security (scans, Allow an app, profiles, USB), personalize, Alt+F4, Win+X
  local x=/usr/libexec n
  for n in mountain-windows-boot mountain-usbguard mountain-personalize mountain-winx mountain-run; do
    [[ -x $x/$n ]] || fail "$n not executable"; bash -n $x/$n || fail "$n syntax"
  done
  assert_cmd efibootmgr
  assert_cmd usbguard
  assert_cmd kdialog
  [[ $(systemctl is-enabled usbguard.service 2>/dev/null) == enabled ]] && fail "USB protection must be opt-in (gaming peripherals)"
  python3 -c 'import sys,xml.etree.ElementTree as E; r=E.parse(sys.argv[1]).getroot(); a=r.find("action"); assert a.find("defaults/allow_active").text=="yes" and a.find("annotate").text=="/usr/libexec/mountain-windows-boot"' /usr/share/polkit-1/actions/org.mountain.windows-boot.policy || fail "Restart into Windows policy"
  assert_grep 'mountain-windows-boot check' /usr/share/plasma/plasmoids/menu.11.enhanced/contents/ui/Footer.qml
  assert_grep 'Restart into Windows' /usr/share/plasma/plasmoids/menu.11.enhanced/contents/ui/Footer.qml
  for n in quick full scan-notify quarantine-restore allow profile usb; do assert_grep "$n" $x/mountain-security; done
  ! grep -qE -- "--exclude=[^ ]*tmp" $x/mountain-security || fail "finished .tmp files are never scanned"
  assert_grep 'Exec=/usr/libexec/mountain-security scan-notify %F' /usr/share/kio/servicemenus/mountain-scan.desktop
  # one Downloads scanner: Active Protection (the English-only %h/Downloads path unit is gone)
  [[ ! -e /usr/lib/systemd/user/mountain-scan-downloads.path ]] || fail "the English-only Downloads path unit is back"
  assert_grep 'is-active mountain-protect.service' $x/mountain-security
  [[ $(systemctl --global is-enabled mountain-protect.service 2>/dev/null) == enabled ]] || fail "Active Protection off"
  assert_cmd inotifywait
  assert_grep '^MemoryHigh=150M$' /usr/lib/systemd/user/mountain-protect.service
  [[ -x /usr/libexec/mountain-protect ]] && bash -n /usr/libexec/mountain-protect || fail "mountain-protect"
  grep -q 'Steam' /usr/libexec/mountain-protect && grep -qE 'rec=.*Steam' /usr/libexec/mountain-protect && fail "Active Protection watches games"
  desktop-file-validate /usr/share/applications/org.mountain.protection.desktop || fail "Active Protection launcher"
  assert_file /usr/share/plasma/plasmoids/org.mountain.settings/contents/ui/ProtectionPage.qml
  assert_grep '^deny = 5$' /etc/security/faillock.conf
  grep -qs pam_faillock /etc/pam.d/system-auth || fail "pam_faillock not in system-auth (5 wrong passwords would not lock)"
  assert_grep 'repair-etc)' /usr/libexec/mountain-security
  python3 -c 'import sys,xml.etree.ElementTree as E; E.parse(sys.argv[1])' /etc/firewalld/zones/mountain-home.xml || fail "bad home zone"
  grep -q 'port ' /etc/firewalld/zones/mountain-home.xml && fail "home profile opens ports"
  assert_grep '^Storage=none$' /usr/lib/systemd/coredump.conf.d/60-mountain.conf
  assert_grep 'registerShortcut("WindowsAltF4"' /usr/share/kwin/scripts/mountain-altf4/contents/code/main.js
  assert_grep '^mountain-altf4Enabled=true$' /etc/xdg/kwinrc
  assert_grep '^Window Close=none,' /etc/skel/.config/kglobalshortcutsrc
  [[ ! -e /etc/xdg/kglobalshortcutsrc ]] || fail "shortcuts in /etc/xdg are ignored by kglobalaccel"
  for f in /usr/share/kglobalaccel/org.kde.plasma-systemmonitor.desktop /usr/share/applications/org.kde.plasma-systemmonitor.desktop; do
    [[ ! -e $f ]] || assert_grep '^X-KDE-Shortcuts=Ctrl+Shift+Esc,Ctrl+Esc$' "$f"
  done
  assert_file /usr/libexec/mountain-shortcuts; [[ -x /usr/libexec/mountain-shortcuts ]] || fail "mountain-shortcuts not executable"
  assert_grep 'Meta+N' /usr/libexec/mountain-shortcuts
  assert_grep '/etc/sddm.conf.d/\*.conf /usr/lib/sddm/sddm.conf.d/\*.conf' /usr/libexec/mountain-user-setup # autologin found in every login-manager folder
  assert_grep '/etc/plasmalogin.conf.d/\*.conf' /usr/libexec/mountain-user-setup
  grep -q 'out == \*set=\[2-9\]\*' /usr/libexec/mountain-shortcuts || fail "mountain-shortcuts marks itself done before both applets are set"
  assert_grep '^Exec=/usr/libexec/mountain-shortcuts$' /etc/xdg/autostart/mountain-shortcuts.desktop
  assert_grep 'FirewallD1.info' /usr/share/polkit-1/rules.d/60-mountain.rules
  assert_grep '^X-KDE-Shortcuts=Meta+X$' /usr/share/applications/mountain-winx.desktop
  assert_grep 'GTA Online and FiveM' /usr/share/plasma/plasmoids/org.mountain.settings/contents/ui/main.qml
  assert_grep 'mountain-personalize glass toggle' /usr/share/plasma/plasmoids/org.mountain.settings/contents/ui/main.qml
  # Windows 11 tokens: one accent blue, 32 px title bar, Body 10.5 pt / Caption 9 pt
  assert_grep '^AccentColor=0,120,212$' /etc/xdg/kdeglobals
  assert_grep '^highlight.color=#0078D4$' /usr/share/Kvantum/BlackGlass/BlackGlass.kvconfig
  assert_grep '^TitleHeight=32$' /usr/share/aurorae/themes/BlackGlass/BlackGlassrc
  assert_grep '^font=Noto Sans,10.5,' /etc/xdg/kdeglobals
  true
}

check_phase32() { # v6: the start menu, panels and login/lock greeter load their QML (a broken import must fail the build, not ship)
  local f m p q d n Q='/usr/lib64/qt6/qml /usr/lib/qt6/qml'
  # every dotted "import X.Y" in our plasmoids, sensor face and the lock screen shell must resolve to an installed module
  for m in $({ grep -rhoE '^import +[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+' /usr/share/plasma/plasmoids/{menu.11.enhanced,org.mountain.*}       /usr/share/ksysguard/sensorfaces/org.mountain.* /usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen 2>/dev/null || true; } | awk '{print $2}' | sort -u); do
    p=${m//.//}; n=0
    for q in $Q; do [[ -f $q/$p/qmldir ]] && n=1; done
    [[ $n == 1 ]] || fail "QML module not installed: $m (start menu or panels would fail to load)"
  done
  # the patched breeze components qmldir (login + lock screen): every type it lists must exist on disk, and nothing may still "prefer" the compiled copy
  d=$(find /usr/lib64/qt6/qml /usr/lib/qt6/qml -type d -path '*/org/kde/breeze/components' -print -quit 2>/dev/null || true)
  [[ -n $d && -f $d/qmldir ]] || fail "breeze components qmldir missing"
  for f in $(awk '$NF ~ /\.(qml|js)$/ && $1 != "prefer" {print $NF}' "$d/qmldir"); do
    [[ -f $d/$f ]] || fail "breeze qmldir lists missing file: $f"
  done
  ! grep -q '^prefer ' "$d/qmldir" || fail "breeze qmldir still prefers the compiled copy"
  for f in "$d"/*.qml; do
    for m in $({ grep -hoE '^import +[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+' "$f" || true; } | awk '{print $2}' | sort -u); do # || true: no dotted import is fine (the ERR trap would print into the list)
      p=${m//.//}; n=0
      for q in $Q; do [[ -f $q/$p/qmldir ]] && n=1; done
      [[ $n == 1 ]] || fail "$(basename "$f"): QML module not installed: $m"
    done
  done
}

check_phase33() { # v6 fix wave: Windows names, flyouts, File Explorer, Settings Background, Protection, Task Manager, dialogs, taskbar
  local a=/usr/share/applications f t d s ui=/usr/share/plasma/plasmoids/org.mountain.settings/contents/ui
  local L=/usr/share/plasma/look-and-feel/org.mountain.desktop/contents/layouts/org.kde.plasma.desktop-layout.js
  # lite mode once per account; Flatpak policy marker
  grep -qF '&& -e $mark ]]; then exit 0' /usr/libexec/mountain-lite-mode || fail "lite mode no longer runs once per account"
  assert_grep 'flatpak-tight-' /usr/libexec/mountain-flatpak-policy
  # Windows app names in menus and title bars, toast headers, PDF Reader icon
  for t in "org.kde.okular:PDF Reader" "org.kde.kcalc:Calculator" "org.kde.kolourpaint:Paint" "org.kde.kwrite:Notepad" "org.kde.konsole:Terminal" "org.kde.plasma-systemmonitor:Task Manager" "org.kde.kdeconnect.app:Phone Link"; do
    assert_grep "^Name=${t#*:}\$" "$a/${t%%:*}.desktop"
  done
  python3 -c 'import gettext,glob; v={x for f in glob.glob("/usr/share/locale/en@mountain/LC_MESSAGES/*.mo") for x in gettext.GNUTranslations(open(f,"rb"))._catalog.values()}; m={"Calculator","PDF Reader","Terminal","Paint","File Explorer"}-v; assert not m, m' || fail "title-bar name catalogs missing"
  # File Explorer labels as in Windows (New, Sort; Quick access / This PC in the side pane), kept after explorer-title.sh merged in
  python3 -c 'import gettext,sys; c=lambda n: {k.split("\x04")[-1]: v for k, v in gettext.GNUTranslations(open("/usr/share/locale/en@mountain/LC_MESSAGES/"+n+".mo","rb"))._catalog.items() if k}; d=c("dolphin"); k=c("kio6"); assert d.get("Create New")=="New" and d.get("Sort By")=="Sort" and d.get("Dolphin")=="File Explorer" and k.get("Places")=="Quick access", (d, k)' || fail "File Explorer labels (New, Sort, Quick access) missing"
  ! grep -rn 'notify-send [^>]' /usr/libexec/mountain-* | grep -v 'notify-send -a ' || fail "notify-send without -a (toast header says notify-send)"
  f=$(find /usr/share/icons/We10X* -name 'okular.*' -print -quit 2>/dev/null || true); [[ -z $f || $(readlink "$f") == */application-pdf.svg ]] || fail "PDF Reader still uses the We10X okular (Outlook-like) icon"
  ! grep -rqx 'Name=Konsole' /etc/skel/Desktop || fail "Konsole name on a desktop launcher"
  # Win+Z snap layouts, Win+V clipboard, Win+. emoji flyout, Win+Shift+S snip
  for s in snaplayouts clipboard; do
    assert_grep '"X-Plasma-API": "declarativescript"' /usr/share/kwin/scripts/org.mountain.$s/metadata.json
    assert_file /usr/share/kwin/scripts/org.mountain.$s/contents/ui/main.qml
    assert_grep "^org.mountain.${s}Enabled=true$" /etc/xdg/kwinrc
  done
  # org.kde.kwin has an uncreatable Window type of its own: a KWin script's own window must be QtQuick's, by qualified name
  for f in $(grep -rl '^import org.kde.kwin' /usr/share/kwin/scripts/org.mountain.* 2>/dev/null || true); do
    ! grep -qzP '(?<![.\w])Window\s*\{' "$f" || fail "bare Window {} in a KWin script resolves to KWin's own type: $f"
  done
  assert_grep '^MountainSnapLayouts=Meta+Z,' /etc/skel/.config/kglobalshortcutsrc
  assert_grep '^MountainClipboard=Meta+V,' /etc/skel/.config/kglobalshortcutsrc
  assert_grep '^show-on-mouse-pos=none,' /etc/skel/.config/kglobalshortcutsrc
  grep -q '^Edit Tiles=Meta+Z' /etc/skel/.config/kglobalshortcutsrc && fail "Win+Z opens the tile editor"
  assert_grep '^wmclass=emojier$' /etc/xdg/kwinrulesrc
  python3 - <<'PY' || fail "kwinrulesrc: [General] count/rules do not match the rule groups"
import configparser
c = configparser.RawConfigParser(strict=True); c.optionxform = str; c.read("/etc/xdg/kwinrulesrc")
r = c["General"]["rules"].split(",")
assert int(c["General"]["count"]) == len(r) and all(c.has_section(x) for x in r), r
PY
  desktop-file-validate $a/org.mountain.snip.desktop || fail "snip launcher"
  assert_grep '^_launch=Meta+Shift+S$' /etc/skel/.config/kglobalshortcutsrc
  assert_grep '^useReleaseToCapture=true$' /etc/xdg/spectaclerc
  assert_cmd spectacle
  assert_cmd plasma-emojier
  # File Explorer: no free-space status, short Details pane, 1100x700, This PC and Network, drag moves on the same drive
  assert_grep '^ShowStatusBar=Small$' /etc/xdg/dolphinrc
  assert_grep '^tags=false$' /etc/xdg/baloofileinformationrc
  assert_grep '^rating=false$' /etc/xdg/baloofileinformationrc
  assert_grep '^userComment=false$' /etc/xdg/baloofileinformationrc
  assert_grep '^wmclass=org.kde.dolphin$' /etc/xdg/kwinrulesrc
  assert_grep '^size=1100,700$' /etc/xdg/kwinrulesrc
  assert_grep '<title>This PC</title>' /usr/share/mountain/user-places.xbel.in
  assert_grep 'href="remote:/"' /usr/share/mountain/user-places.xbel.in
  assert_grep '^DndBehavior=MoveIfSameDevice$' /etc/xdg/kdeglobals
  # Settings: native Background page, no Linux jargon, Protection page polls only when shown
  assert_file $ui/BackgroundPage.qml
  [[ -x /usr/libexec/mountain-background ]] || fail "mountain-background missing or not executable"
  bash -n /usr/libexec/mountain-background || fail "mountain-background: syntax error"
  grep -q 'kcm_wallpaper' $ui/main.qml && fail "Settings > Background still opens KDE System Settings"
  assert_grep 'page: "background"' $ui/main.qml
  assert_grep 'hostWindow.active' $ui/ProtectionPage.qml
  grep -q 'running: true' $ui/ProtectionPage.qml && fail "Active Protection page polls when hidden"
  grep -rhoE '[{ ;](d|text|details|details2|title|subtitle): "[^"]*"' $ui | grep -iE 'colour|centre|KDE|MangoHud|ProtonDB|Btrfs|SELinux|Flatpak|firewalld|polkit|ClamAV|usbguard|bootc|rpm-ostree|snapshot|sandbox' \
    && fail "Linux jargon or UK spelling in Settings text"
  # Active Protection: file names never become a program, sandboxed scans, /tmp one level only, light status
  grep -q 'sed -i' /usr/libexec/mountain-protect && fail "mountain-protect: file names must never become a sed program"
  for s in PrivateNetwork=yes NoNewPrivileges=yes ProtectSystem=strict ProtectHome=read-only MemoryMax= ReadWritePaths= allow-hash xdg-user-dir 'status --av'; do assert_grep "$s" /usr/libexec/mountain-protect; done
  grep -qE 'inotifywait -mrq[^#]*/tmp' /usr/libexec/mountain-protect && fail "Active Protection watches /tmp recursively"
  assert_grep 'SystemCallFilter=@system-service' /usr/libexec/mountain-protect
  assert_grep 'pkill -u "$(id -u)" -x kdeconnectd' /usr/libexec/mountain-phonelink
  assert_grep '.games-$n' /usr/libexec/mountain-snapshot # game folders made once per account, not every hour
  # File Explorer: Details pane follows the selection with short dates; Previous versions only for local files; no folder icons on launchers
  assert_grep '^\[InformationPanel\]$' /etc/xdg/dolphinrc
  assert_grep '^dateFormat=ShortFormat$' /etc/xdg/dolphinrc
  assert_grep '^showHovered=false$' /etc/xdg/dolphinrc
  assert_grep '^X-KDE-Protocols=file$' /usr/share/kio/servicemenus/mountain-previous-versions.desktop
  ! grep -rlx 'Icon=mountain-folder-.*' /etc/skel/Desktop --include='*' --exclude=.directory /usr/share/applications 2>/dev/null | grep -q . || fail "a launcher uses a folder icon"
  for k in kfileitem#type kfileitem#size kfileitem#modified kfileitem#created; do grep -qx "$k=false" /etc/xdg/baloofileinformationrc && fail "Details pane hides $k"; done
  # Task Manager Startup apps: Windows columns, Mountain/desktop internals hidden; the services list updates in place
  assert_file /usr/libexec/mountain-taskmanager-startup
  f=$(bash /usr/libexec/mountain-taskmanager-startup || true)
  [[ $f == $'id\tName\tPublisher\tStatus\tStartup impact'* ]] || fail "Task Manager startup list lacks Windows columns"
  grep -qE '^(mountain-|baloo)' <<<"$f" && fail "Startup apps shows Mountain internals"
  grep -q $'\t/usr/libexec/' <<<"$f" && fail "Startup apps shows libexec paths"
  f=/usr/share/ksysguard/sensorfaces/org.mountain.taskmanager.list/contents/ui/FullRepresentation.qml
  assert_grep 'mountain-taskmanager-startup' $f
  assert_grep 'model: rowModel' $f
  assert_grep '!root.busy && !listHover.hovered' $f
  bad=$({ grep -ho 'SensorIds=.*\|totalSensors=.*' /usr/share/plasma-systemmonitor/mountain-*.page || true; } | { grep -o '"[^"]*"' || true; } | tr -d '"' | sort -u | { grep -vxE 'cpu/all/usage|memory/physical/(used|total)|disk/all/(read|write)|network/all/(download|upload)' || true; })
  [[ -z $bad ]] || fail "Task Manager pages use sensors a PC may lack: $bad"
  assert_grep 'plasma-systemmonitor/mountain-' /usr/libexec/mountain-user-setup # old saved pages (GPU chart) cleared
  # taskbar: quick settings glyphs and feedback, top bar as text
  qs=/usr/share/plasma/plasmoids/org.mountain.quicksettings/contents/ui
  assert_grep 'iconSizes.smallMedium' $qs/main.qml
  assert_grep 'expandedFeedback' $qs/main.qml
  assert_grep '"preferences-system-symbolic"' $qs/main.qml
  grep -q '"configure-symbolic"' $qs/main.qml && fail "quick settings gear is KDE's configure glyph"
  assert_grep '"go-next-symbolic"' $qs/VolumeRow.qml
  assert_grep 'org.kde.ksysguard.textonly' /usr/libexec/mountain-topbar
  t=$({ grep -c 'org.kde.plasma.systemmonitor.\(cpu\|memory\)' /usr/libexec/mountain-topbar || true; }); [[ $t -ge 2 ]] || fail "top bar lost the CPU/RAM applets"
  # start menu: Windows 11 header and footer, Best match, dialog tokens
  mu=/usr/share/plasma/plasmoids/menu.11.enhanced/contents/ui
  assert_file $mu/Pill.qml
  assert_grep 'text: i18n("All")' $mu/MenuRepresentation.qml
  assert_grep 'i18n("Best match")' $mu/ItemMultiGridView.qml
  assert_grep 'Kirigami.Avatar' $mu/Footer.qml
  [[ -z $(grep -E "icon.name: +\"(user-home|configure)\"" $mu/Footer.qml || true) ]] || fail "start menu footer has more than account and power"
  [[ -z $(grep -E "source: '(bookmarks|tag-recents|view-grid)'" $mu/MenuRepresentation.qml || true) ]] || fail "start menu section titles carry KDE icons"
  [[ -z $(grep -l '#F2F3F5' /usr/share/plasma/plasmoids/org.mountain.{run,winx,shutdown}/contents/ui/main.qml || true) ]] || fail "Run / Win+X / Shut Down text is not #FFFFFF"
  # Task Manager Background processes: Mountain face with Windows names, End task only for own processes
  assert_grep '^mode=processes$' /usr/share/plasma-systemmonitor/mountain-1-processes.page
  assert_grep '^actionsFace=Face-880000000001$' /usr/share/plasma-systemmonitor/mountain-1-processes.page
  assert_grep 'Kirigami.PromptDialog' /usr/share/ksysguard/sensorfaces/org.mountain.taskmanager.list/contents/ui/FullRepresentation.qml
  f=$(/usr/libexec/mountain-taskmanager processes || true); [[ $f == $'id\tName\tCPU\tMemory'* ]] || fail "Task Manager background processes list"
  /usr/libexec/mountain-taskmanager end '1;true' 2>/dev/null && fail "End task accepts a non-numeric pid"
  /usr/libexec/mountain-taskmanager end 1 2>/dev/null && fail "End task accepts pid 1 (or runs as root)"
  assert_grep 'plasmashell=Windows Explorer' /usr/libexec/mountain-taskmanager
  # app strings: Phone Link, Notepad welcome page, Camera (only from catalogs the image actually has)
  for c in kdeconnect-app kate kamoso; do
    [[ -f /usr/share/locale/de/LC_MESSAGES/$c.mo ]] || continue
    [[ -f /usr/share/locale/en@mountain/LC_MESSAGES/$c.mo ]] || fail "no en@mountain catalog for $c"
  done
  v=$(python3 -c 'import gettext,glob; print("\n".join(v for f in glob.glob("/usr/share/locale/en@mountain/LC_MESSAGES/*.mo") for v in gettext.GNUTranslations(open(f,"rb"))._catalog.values()))' || true)
  grep -qx 'About Phone Link' <<<"$v" || fail "Phone Link About string not renamed"
  grep -qx 'Send feedback' <<<"$v" || fail "Notepad welcome page still says Get involved"
  # Windows 11 menus and 8 px corners, no Overview hot corner, yellow folders, no classic menubars
  f=/usr/share/Kvantum/BlackGlass/BlackGlass.kvconfig
  for p in '^frame.left=8$' '^menu_shadow_depth=8$' '^menu_blur_radius=8$' '^reduce_menu_opacity=6$' '^text.iconspacing=12$'; do assert_grep "$p" $f; done
  for f in /usr/share/Kvantum/BlackGlass/BlackGlass.svg /usr/share/Kvantum/BlackGlassSolid/BlackGlassSolid.svg; do assert_grep 'id="menu-shadow-topleft"' $f; done
  assert_grep 'id="menu-shadow-hint-left"' /usr/share/Kvantum/BlackGlass/BlackGlass.svg
  [[ -z "$(grep -o 'A10,10' /usr/share/aurorae/themes/BlackGlass/decoration.svg || true)" ]] || fail "window corners are not 8 px"
  assert_grep 'A8,8 0 0 1 32,20' /usr/share/aurorae/themes/BlackGlass/decoration.svg
  assert_grep '^\[Effect-overview\]$' /etc/xdg/kwinrc
  assert_grep '^BorderActivate=9$' /etc/xdg/kwinrc
  assert_grep '^MenuBar=Disabled$' /etc/xdg/okularrc
  assert_grep '^MenuBar=Disabled$' /etc/xdg/gwenviewrc
  assert_grep '^StatusBar=Disabled$' /etc/xdg/kolourpaintrc
  for f in /usr/share/icons/hicolor/scalable/places/mountain-folder-*.svg; do
    assert_grep 'stop-color="#FFD866"' "$f"
    [[ -z "$(grep -o '#475569\|#334155' "$f" || true)" ]] || fail "slate folder left: $f"
  done
  # Settings: Windows "Network & internet" rows, no polling; focus ring apart from the selected pill; 4 px buttons
  su=/usr/share/plasma/plasmoids/org.mountain.settings/contents/ui
  assert_file $su/NetworkPage.qml
  assert_grep 'NetworkPage.qml' $su/main.qml
  assert_grep 'app.netFailed' $su/main.qml # falls back to the plain rows without plasma-nm
  for t in 'Wi-Fi' 'Ethernet' 'VPN' 'Mobile hotspot' 'Airplane mode' 'Proxy' 'Advanced network settings'; do assert_grep "{ t: \"$t\"" $su/main.qml; done
  assert_grep 'handler.enableAirplaneMode(on)' $su/NetworkPage.qml
  n=$({ grep -c 'Timer' $su/NetworkPage.qml || true; }); [[ $n == 0 ]] || fail "Network page polls"
  assert_grep 'navButton.visualFocus ? 2 : 0' $su/main.qml
  n=$({ grep -A1 'background: Rectangle' $su/GlassButton.qml | grep -c 'radius: 4' || true; }); [[ $n == 1 ]] || fail "Settings buttons not 4 px"
  assert_grep 'Environment=MOUNTAIN_SCAN_REPORT_ONLY=1' /usr/libexec/mountain-protect
  assert_grep '/.local/share/kwin/scripts' /usr/libexec/mountain-protect
  assert_grep "split(\"'\").join" /usr/share/plasma/plasmoids/org.mountain.settings/contents/ui/main.qml # wallpaper path shell-quoted
  assert_cmd xdg-user-dir
  assert_grep 'allow-hash "$quarantine/' /usr/libexec/mountain-security
  # snapshots: low-disk keep rule, game libraries as subvolumes; definitions download can't be looped
  assert_grep '^StartLimitBurst=3$' /usr/lib/systemd/system/mountain-virus-definitions.service
  assert_grep 'recent=3; days=3' /usr/libexec/mountain-snapshot
  assert_grep 'btrfs subvolume create' /usr/libexec/mountain-user-setup
  # Task Manager: no Edit Page, CPU 0-100 %, no missing GPU sensors, startup toggle takes any .desktop name
  for f in /usr/share/plasma-systemmonitor/mountain-*.page; do
    grep -q '^actionsFace=Face-' "$f" || fail "Task Manager page shows Edit Page: $f"
  done
  grep -q 'gpu/all/usage\|gpu_usage' /usr/share/plasma-systemmonitor/mountain-*.page && fail "Task Manager uses GPU sensors that are missing without a GPU"
  for f in 1-processes 3-apphistory 6-details; do
    assert_grep '"usage":"textScaled"' /usr/share/plasma-systemmonitor/mountain-$f.page
  done
  d=$(mktemp -d); mkdir -p "$d/autostart"; printf '[Desktop Entry]\nName=T\nExec=true\n' > "$d/autostart/Тест App.desktop"
  XDG_CONFIG_HOME=$d MOUNTAIN_AUTOSTART_SYSTEM=$d/none /usr/libexec/mountain-taskmanager startup-set "Тест App.desktop" off || fail "startup toggle rejects a name with a space or Cyrillic"
  grep -q '^Hidden=true' "$d/autostart/Тест App.desktop" || fail "startup toggle did not turn it off"
  XDG_CONFIG_HOME=$d /usr/libexec/mountain-taskmanager startup-set ../x.desktop off 2>/dev/null && fail "startup toggle accepts a path"
  rm -rf "$d"
  # Win+R Run, Win+X Quick Link menu, Alt+F4 Shut Down: plasmawindowed dialogs placed by the mountain-altf4 KWin script
  for s in run winx shutdown; do
    python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["KPlugin"]["Id"] == sys.argv[2]' /usr/share/plasma/plasmoids/org.mountain.$s/metadata.json org.mountain.$s || fail "org.mountain.$s metadata"
    assert_file /usr/share/plasma/plasmoids/org.mountain.$s/contents/ui/main.qml
  done
  assert_grep 'exec plasmawindowed org.mountain.winx' /usr/libexec/mountain-winx
  assert_grep 'mountain-shutdown-dialog.service' /usr/share/kwin/scripts/mountain-altf4/contents/code/main.js
  assert_grep 'plasmawindowed org.mountain.shutdown' /usr/lib/systemd/user/mountain-shutdown-dialog.service
  grep -q 'kdialog' /usr/libexec/mountain-winx && fail "Win+X is still a kdialog list"
  desktop-file-validate $a/org.mountain.run.desktop || fail "Run launcher"
  assert_cmd plasmawindowed; assert_cmd setsid; assert_cmd gio; assert_cmd xdg-open
  python3 - <<'PY' || fail "dialog QML: accessible names and Esc"
for n in ("run", "winx", "shutdown"):
    s = open(f"/usr/share/plasma/plasmoids/org.mountain.{n}/contents/ui/main.qml").read()
    assert "Accessible.name" in s and ("onEscapePressed" in s or "Key_Escape" in s), n
PY
  d=$(find /usr/lib64/qt6/qml /usr/lib/qt6/qml -type d -path '*/org/kde/plasma/private/sessions' -print -quit 2>/dev/null || true); [[ -n $d ]] || fail "SessionManagement QML module missing (Shut Down / Win+X power items)"
  # taskbar: floating flyouts, one bell, ^ first, M/d/yyyy clock, show-desktop sliver, toasts bottom right 5 s, stronger desktop label shadow
  python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["KPlugin"]["Id"]=="org.mountain.showdesktop"' /usr/share/plasma/plasmoids/org.mountain.showdesktop/metadata.json || fail "bad show-desktop metadata"
  assert_file /usr/share/plasma/plasmoids/org.mountain.showdesktop/contents/ui/main.qml
  assert_grep 'org.mountain.showdesktop' "$L"
  assert_grep 'panel.floatingApplets = true' "$L"
  assert_grep '"knownItems", knownItems' "$L"
  assert_grep '"reverseIconOrder", true' "$L"
  assert_grep '"customDateFormat", "M/d/yyyy"' "$L"
  assert_grep '^PopupPosition=BottomRight$' /etc/xdg/plasmanotifyrc
  assert_grep '^PopupTimeout=5000$' /etc/xdg/plasmanotifyrc
  assert_grep 'Not available' /usr/share/plasma/plasmoids/org.mountain.quicksettings/contents/ui/Tile.qml
  grep -rq 'unavailable")' /usr/share/plasma/plasmoids/org.mountain.quicksettings/contents/ui && fail "quick-settings tile names too long for the tile"
  f=$(find /usr/lib64/qt6/qml /usr/lib/qt6/qml -path '*/org/kde/plasma/extras/ShadowedLabel.qml' -print -quit 2>/dev/null || true); grep -qs 'spread: 0.55' "$f" || fail "desktop label shadow not patched"
  assert_grep '^LANG=' /etc/locale.conf # sign-in screen clock follows US English (12 h, M/d) unless the installer chose another language
  true
}

# every check_phaseN defined above runs, so a new phase can never be forgotten
phases=$(declare -F | awk '{print $3}' | grep -E '^check_phase[0-9]+$' | sort -V)
[[ -n $phases ]] || fail "no check_phase functions found"
for fn in $phases; do "$fn"; done
echo "PASS: $(echo "$phases" | wc -l) phases"
