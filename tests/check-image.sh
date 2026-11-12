#!/usr/bin/env bash
set -Eeuo pipefail # -E: the FAIL line trap also fires inside the phase functions
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
  assert_grep '^theme=BlackGlass$' /etc/xdg/Kvantum/kvantum.kvconfig # v5: BlackGlass replaced GlassDark as the default
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
  else echo "NOTE: lsinitrd missing, initramfs watermark not checked"; fi
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
  assert_grep 'steam-streaming' /etc/firewalld/zones/mountain.xml
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
  MOUNTAIN_RENDERER=llvmpipe HOME=$(mktemp -d) bash -c 'mkdir -p ~/.config/Kvantum; printf "[General]\ntheme=BlackGlass\n" > ~/.config/Kvantum/kvantum.kvconfig; /usr/libexec/mountain-lite-mode >/dev/null; grep -q "^theme=BlackGlassSolid$" ~/.config/Kvantum/kvantum.kvconfig' || fail "lite mode keeps see-through app windows"
  true
}

check_phase29() { # v6 (was v5.1): brightness, sharp solid windows, File Explorer layout, Task Manager, Security, snapshots, hardening
  local q=/usr/share/plasma/plasmoids/org.mountain.quicksettings/contents/ui f n
  assert_grep 'Not available on this display' $q/BrightnessRow.qml
  grep -q 'item.visible' $q/main.qml && fail "brightness row can still disappear"
  # File Explorer: tab bar only with 2+ tabs, full-width status bar, sidebar wide enough for "Documents"/"Recycle Bin"/"Previous versions"
  assert_grep '^AlwaysShowTabBar=false$' /etc/xdg/dolphinrc
  assert_grep '^ShowStatusBar=FullWidth$' /etc/xdg/dolphinrc
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
  grep -qs '^X-KDE-Shortcuts=Meta+R,' $a/org.kde.krunner.desktop /usr/share/kglobalaccel/org.kde.krunner.desktop || fail "Win+R not bound"
  assert_grep '^X-KDE-Shortcuts=Meta+E$' $a/org.kde.dolphin.desktop
  assert_grep $'^Overview=Meta+Tab\tMeta+W,' /etc/xdg/kglobalshortcutsrc
  assert_grep '^next activity=none,' /etc/xdg/kglobalshortcutsrc
  assert_grep '^toggle_hud=Super_L+g$' /etc/xdg/MangoHud/MangoHud.conf
  assert_grep '^MANGOHUD=1$' /usr/lib/environment.d/60-mountain-mangohud.conf
  assert_grep '^MANGOHUD_CONFIGFILE=/etc/xdg/MangoHud/MangoHud.conf$' /usr/lib/environment.d/60-mountain-mangohud.conf
  assert_grep '^clipboardGroup=PostScreenshotCopyImage$' /etc/xdg/spectaclerc
  # Bulgarian keyboard, Cyrillic fonts
  assert_grep '^LayoutList=us,bg,bg$' /etc/xdg/kxkbrc
  assert_grep '^VariantList=,phonetic,$' /etc/xdg/kxkbrc
  assert_grep '^Options=grp:alt_shift_toggle$' /etc/xdg/kxkbrc
  fc-list :lang=bg family | grep -q . || fail "no font covers Bulgarian"
  # Windows 11 taskbar: 48 px, not floating, show-desktop corner
  assert_grep 'panel.height = 48' "$L"
  assert_grep 'panel.floating = false' "$L"
  assert_grep 'org.kde.plasma.showdesktop' "$L"
  # Phone Link starts KDE Connect only when opened; Restore previous versions; Reset this PC
  assert_grep '^Exec=/usr/libexec/mountain-phonelink$' $a/org.kde.kdeconnect.app.desktop
  [[ ! -e /usr/share/dbus-1/services/org.kde.kdeconnect.service ]] || fail "Phone Link daemon D-Bus activated (background drain)"
  assert_grep 'kdeconnect' /etc/firewalld/zones/mountain.xml
  assert_grep 'Exec=/usr/libexec/mountain-previous-versions %f' /usr/share/kio/servicemenus/mountain-previous-versions.desktop
  for n in mountain-phonelink mountain-previous-versions; do [[ -x /usr/libexec/$n ]] || fail "$n not executable"; bash -n /usr/libexec/$n || fail "$n syntax"; done
  assert_grep 'reset) reset_pc' /usr/libexec/mountain-security
  for n in kcalc kclock kolourpaint kamoso krecorder skanlite spectacle; do assert_cmd $n; done
  true
}

check_phase31() { # v6 brief: Restart into Windows, full Security (scans, Allow an app, profiles, USB), personalize, Alt+F4, Win+X
  local x=/usr/libexec n
  for n in mountain-windows-boot mountain-usbguard mountain-personalize mountain-winx; do
    [[ -x $x/$n ]] || fail "$n not executable"; bash -n $x/$n || fail "$n syntax"
  done
  assert_cmd efibootmgr
  assert_cmd usbguard
  assert_cmd kdialog
  [[ $(systemctl is-enabled usbguard.service 2>/dev/null) == enabled ]] && fail "USB protection must be opt-in (gaming peripherals)"
  python3 -c 'import sys,xml.etree.ElementTree as E; r=E.parse(sys.argv[1]).getroot(); a=r.find("action"); assert a.find("defaults/allow_active").text=="yes" and a.find("annotate").text=="/usr/libexec/mountain-windows-boot"' /usr/share/polkit-1/actions/org.mountain.windows-boot.policy || fail "Restart into Windows policy"
  assert_grep 'mountain-windows-boot check' /usr/share/plasma/plasmoids/menu.11.enhanced/contents/ui/Footer.qml
  assert_grep 'Restart into Windows' /usr/share/plasma/plasmoids/menu.11.enhanced/contents/ui/Footer.qml
  for n in quick full scan-new scan-notify quarantine-restore allow profile usb; do assert_grep "$n" $x/mountain-security; done
  assert_grep 'Exec=/usr/libexec/mountain-security scan-notify %F' /usr/share/kio/servicemenus/mountain-scan.desktop
  assert_grep 'PathChanged=%h/Downloads' /usr/lib/systemd/user/mountain-scan-downloads.path
  [[ $(systemctl --global is-enabled mountain-scan-downloads.path 2>/dev/null) == enabled ]] || fail "Downloads watcher off"
  python3 -c 'import sys,xml.etree.ElementTree as E; E.parse(sys.argv[1])' /etc/firewalld/zones/mountain-home.xml || fail "bad home zone"
  grep -q 'port ' /etc/firewalld/zones/mountain-home.xml && fail "home profile opens ports"
  assert_grep '^Storage=none$' /usr/lib/systemd/coredump.conf.d/60-mountain.conf
  assert_grep 'registerShortcut("WindowsAltF4"' /usr/share/kwin/scripts/mountain-altf4/contents/code/main.js
  assert_grep '^mountain-altf4Enabled=true$' /etc/xdg/kwinrc
  assert_grep '^Window Close=none,' /etc/xdg/kglobalshortcutsrc
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

PHASE=${1:-0}
for p in $(seq 0 "$PHASE"); do
  fn="check_phase$p"
  if declare -F "$fn" >/dev/null; then
    "$fn"
  fi
done
echo "PASS: phase $PHASE"
