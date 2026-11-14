#!/bin/bash
# Test-only: fake Wi-Fi, Bluetooth, camera, printer and game pad inside the vm-test VM (run as root).
# Nothing here is part of the image: packages go into a throw-away /usr overlay, from repos the image already has.
# Output: one line per call, "OK <what> ...", "SKIP <what>: <reason>" (exit 3, cannot be faked here) or "FAIL <what>: <reason>" (exit 1).
# Usage: hwsim.sh setup|wifi-up|wifi-join|wifi-leave|bt-up|bt-pair|cam-up|printer-up|printer-print|pad-up|pad-press|brightness|teardown
D=/run/hwsim
SSID=MountainTest
PSK=mountain-test-123
PADNAME="Microsoft X-Box 360 pad"
LOG=$D/log
mkdir -p $D

ok()   { echo "OK $*"; exit 0; }
skip() { echo "SKIP $*"; exit 3; }
fail() { echo "FAIL $*"; exit 1; }
# wait up to $1 seconds for a command (rest of the args) to succeed
waitfor() { local n=$1; shift; while [ "$n" -gt 0 ]; do "$@" >/dev/null 2>&1 && return 0; sleep 1; n=$((n-1)); done; return 1; }

# /usr is read-only on bootc: a transient overlay lets dnf install test tools (gone after reboot)
overlay() {
  findmnt -n -o FSTYPE /usr | grep -q overlay && return 0
  { bootc usr-overlay || rpm-ostree usroverlay; } >>$LOG 2>&1
}
# pkg CMD-OR-FILE PACKAGE-SPEC...: install only when the command is missing (file paths work as dnf provides)
pkg() {
  command -v "$1" >/dev/null 2>&1 && return 0
  shift
  overlay && timeout 300 dnf install -y -q --setopt=install_weak_deps=False "$@" >>$LOG 2>&1
}
# kmod NAME [PACKAGE...]: modprobe, else try installing the matching-kernel package, else fail (caller SKIPs)
kmod() {
  local m=$1; shift
  modprobe "$m" 2>>$LOG && return 0
  [ $# -gt 0 ] && overlay && timeout 300 dnf install -y -q "$@" >>$LOG 2>&1 && depmod -a && modprobe "$m" 2>>$LOG
}
as_user() { sudo -u looktest env XDG_RUNTIME_DIR=/run/user/"$(id -u looktest)" DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/"$(id -u looktest)"/bus "$@"; }
bg() { # NAME CMD...: start detached, remember pid
  local n=$1; shift
  setsid nohup "$@" >>$LOG 2>&1 </dev/null &
  echo $! >$D/$n.pid
}
wifi_ifaces() { for i in /sys/class/net/*/wireless; do [ -e "$i" ] && basename "$(dirname "$i")"; done | sort; }

case $1 in
setup) # no hardware yet; proves the overlay and the repos work
  overlay && ok "setup overlay=$(findmnt -n -o FSTYPE /usr) kernel=$(uname -r)" || fail "setup: no /usr overlay (see $LOG)" ;;

wifi-up)
  kmod mac80211_hwsim "kernel-modules-internal-$(uname -r)" || skip "wifi: mac80211_hwsim missing for kernel $(uname -r) (kernel-modules-internal not in the enabled repos)"
  pkg hostapd hostapd || skip "wifi: hostapd not installable from the enabled repos"
  waitfor 15 test "$(wifi_ifaces | wc -l)" -ge 2 || fail "wifi: hwsim made no radios"
  STA=$(wifi_ifaces | sed -n 1p); AP=$(wifi_ifaces | sed -n 2p)
  nmcli device set "$AP" managed no >>$LOG 2>&1 # the access point side stays out of NetworkManager
  ip link set "$AP" up
  cat >$D/hostapd.conf <<EOF
interface=$AP
driver=nl80211
ssid=$SSID
hw_mode=g
channel=1
wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wpa_passphrase=$PSK
EOF
  bg hostapd hostapd $D/hostapd.conf
  echo "$STA" >$D/sta
  # NM must list the AP; rescan until it does (bounded)
  waitfor 40 bash -c "nmcli device wifi rescan ifname $STA >/dev/null 2>&1; nmcli -t -f SSID device wifi list ifname $STA | grep -qx $SSID" \
    && ok "wifi ap=$SSID sta=$STA ap-if=$AP" || fail "wifi: $SSID not visible to NetworkManager on $STA (see $LOG)" ;;

wifi-join) # as looktest like the user; falls back to root if polkit refuses a non-seat session
  STA=$(cat $D/sta 2>/dev/null) || skip "wifi-join: no wifi-up"
  nmcli connection delete $SSID >/dev/null 2>&1
  # link-local: there is no DHCP server on the fake AP, so do not wait for one
  ADD=(nmcli connection add type wifi ifname "$STA" con-name $SSID ssid $SSID wifi-sec.key-mgmt wpa-psk wifi-sec.psk $PSK ipv4.method link-local ipv6.method disabled)
  UP=(nmcli -w 30 connection up $SSID ifname "$STA")
  if as_user "${ADD[@]}" >>$LOG 2>&1 && as_user "${UP[@]}" >>$LOG 2>&1; then V=looktest
  else nmcli connection delete $SSID >/dev/null 2>&1; "${ADD[@]}" >>$LOG 2>&1 && "${UP[@]}" >>$LOG 2>&1 && V=root; fi
  [ -n "$V" ] || fail "wifi-join: could not connect (see $LOG)"
  waitfor 20 bash -c "nmcli -t -f GENERAL.STATE device show $STA | grep -q '^GENERAL.STATE:100'" \
    && ok "wifi-join ssid=$SSID dev=$STA state=connected as=$V" || fail "wifi-join: $STA not connected" ;;

wifi-leave)
  STA=$(cat $D/sta 2>/dev/null) || skip "wifi-leave: no wifi-up"
  nmcli connection down $SSID >>$LOG 2>&1; nmcli connection delete $SSID >>$LOG 2>&1
  waitfor 15 bash -c "! nmcli -t -f GENERAL.STATE device show $STA | grep -q '^GENERAL.STATE:100'" \
    && ok "wifi-leave dev=$STA state=disconnected" || fail "wifi-leave: $STA still connected" ;;

bt-up) # btvirt (bluez emulator) feeds /dev/vhci: two virtual controllers that can see each other
  kmod hci_vhci || skip "bt: hci_vhci not in kernel $(uname -r)"
  pkg btvirt bluez-tools bluez-test >/dev/null 2>&1 # whichever of these exists; btvirt is not a standard Fedora package
  BTV=$(command -v btvirt || ls /usr/libexec/bluetooth/btvirt /usr/lib/bluez/btvirt 2>/dev/null | head -1)
  [ -n "$BTV" ] || skip "bt: no btvirt in the enabled repos (only the kernel side, hci_vhci, loads)"
  systemctl start bluetooth >>$LOG 2>&1
  bg btvirt "$BTV" -l2
  waitfor 20 bash -c "bluetoothctl list | grep -q Controller" || fail "bt: no controller appeared (see $LOG)"
  bluetoothctl power on >>$LOG 2>&1
  waitfor 10 bash -c "bluetoothctl show | grep -q 'Powered: yes'" \
    && ok "bt controllers=$(bluetoothctl list | grep -c Controller) powered=yes" || fail "bt: controller not powered" ;;

bt-pair) # best effort: controller 2 is discoverable, controller 1 scans, finds and pairs it
  C1=$(bluetoothctl list | sed -n 1p | awk '{print $2}'); C2=$(bluetoothctl list | sed -n 2p | awk '{print $2}')
  [ -n "$C2" ] || skip "bt-pair: needs the two btvirt controllers from bt-up"
  { echo "select $C2"; echo "power on"; echo "pairable on"; echo "discoverable on"; sleep 1
    echo "select $C1"; echo "power on"; echo "scan on"; sleep 12; echo "devices"; echo "scan off"; sleep 1; echo "quit"; } \
    | timeout 40 bluetoothctl >$D/bt-scan.txt 2>&1
  grep -q "Device $C2" $D/bt-scan.txt || skip "bt-pair: controller 1 did not discover controller 2 (BlueZ ignores its own host's adapters)"
  timeout 30 bluetoothctl pair "$C2" >>$LOG 2>&1 && ok "bt-pair device=$C2 paired" || skip "bt-pair: discovered $C2 but pairing needs an agent (found only)" ;;

cam-up)
  kmod v4l2loopback || skip "cam: v4l2loopback kmod not available for kernel $(uname -r) (Bazzite ships it via akmods; it must be in the image)"
  # module options go in at load time; reload once to get a fixed node and a name
  rmmod v4l2loopback 2>/dev/null
  modprobe v4l2loopback devices=1 video_nr=10 card_label="Mountain Test Camera" exclusive_caps=1 || skip "cam: v4l2loopback would not load"
  waitfor 10 test -e /dev/video10 || fail "cam: no /dev/video10"
  chmod 666 /dev/video10
  if pkg gst-launch-1.0 gstreamer1 gstreamer1-plugins-good && gst-inspect-1.0 v4l2sink >/dev/null 2>&1; then
    bg cam gst-launch-1.0 -q videotestsrc is-live=true pattern=ball ! video/x-raw,format=YUY2,width=640,height=480,framerate=30/1 ! v4l2sink device=/dev/video10; F=gst
  elif pkg ffmpeg ffmpeg-free; then
    bg cam ffmpeg -loglevel error -re -f lavfi -i testsrc=size=640x480:rate=30 -pix_fmt yuyv422 -f v4l2 /dev/video10; F=ffmpeg
  else skip "cam: neither gstreamer v4l2sink nor ffmpeg available to feed the test pattern"; fi
  sleep 3
  kill -0 "$(cat $D/cam.pid)" 2>/dev/null && ok "cam /dev/video10 name='Mountain Test Camera' feeder=$F" || fail "cam: feeder exited (see $LOG)" ;;

printer-up) # driverless IPP printer (ippeveprinter, from cups) + a CUPS queue that uses it
  pkg lpadmin cups || skip "printer: cups not installable"
  pkg ippeveprinter /usr/bin/ippeveprinter || skip "printer: no ippeveprinter in the enabled repos"
  systemctl start cups >>$LOG 2>&1
  mkdir -p /var/tmp/hwsim-spool
  bg printer ippeveprinter -d /var/tmp/hwsim-spool -p 8631 -r off -n localhost "Mountain Test Printer"
  waitfor 20 bash -c "exec 3<>/dev/tcp/127.0.0.1/8631" || fail "printer: ippeveprinter not listening"
  lpadmin -p MountainTest -E -v ipp://localhost:8631/ipp/print -m everywhere >>$LOG 2>&1 || fail "printer: lpadmin refused the queue"
  lpadmin -d MountainTest
  waitfor 15 bash -c "lpstat -p MountainTest | grep -q 'is idle'" \
    && ok "printer MountainTest idle uri=ipp://localhost:8631/ipp/print" || fail "printer: queue not idle ($(lpstat -p MountainTest 2>&1 | head -1))" ;;

printer-print)
  lpstat -p MountainTest >/dev/null 2>&1 || skip "printer-print: no printer-up"
  J=$(lp -d MountainTest /usr/share/cups/data/testprint 2>&1 || lp -d MountainTest /etc/os-release 2>&1)
  ID=$(echo "$J" | grep -o 'MountainTest-[0-9]*' | head -1)
  [ -n "$ID" ] || fail "printer-print: lp said: $J"
  waitfor 40 bash -c "lpstat -W completed -o MountainTest | grep -q '^$ID '" \
    && ok "printer-print job=$ID completed" || fail "printer-print: $ID not completed ($(lpstat -o MountainTest 2>&1 | head -1))" ;;

pad-up) # uinput Xbox 360 pad (vendor 045e:028e); the daemon owns the device and reads commands from a fifo
  kmod uinput || skip "pad: uinput not in kernel $(uname -r)"
  modprobe joydev 2>>$LOG
  waitfor 10 test -e /dev/uinput || skip "pad: no /dev/uinput"
  mkfifo $D/pad.fifo 2>/dev/null
  cat >$D/pad.py <<'PY'
import fcntl, os, struct, sys, time
NAME = sys.argv[1].encode()
f = os.open('/dev/uinput', os.O_WRONLY)
def io(req, v): fcntl.ioctl(f, req, v)
io(0x40045564, 1); io(0x40045564, 3)                      # EV_KEY, EV_ABS
BTNS = (0x130, 0x131, 0x133, 0x134, 0x136, 0x137, 0x13a, 0x13b, 0x13c, 0x13d, 0x13e)
for b in BTNS: io(0x40045565, b)
AX = {0: (-32768, 32767), 1: (-32768, 32767), 2: (0, 255), 3: (-32768, 32767), 4: (-32768, 32767), 5: (0, 255), 0x10: (-1, 1), 0x11: (-1, 1)}
mx = [0] * 64; mn = [0] * 64
for a, (lo, hi) in AX.items(): io(0x40045567, a); mn[a] = lo; mx[a] = hi
os.write(f, struct.pack('80sHHHHi64i64i64i64i', NAME, 3, 0x045e, 0x028e, 0x110, 0, *mx, *mn, *([0] * 128)))
io(0x5501, 0)                                              # UI_DEV_CREATE
def ev(t, c, v): os.write(f, struct.pack('llHHi', 0, 0, t, c, v))
fifo = os.open('/run/hwsim/pad.fifo', os.O_RDWR)           # O_RDWR: never sees EOF
buf = b''
while True:
    buf += os.read(fifo, 64)
    while b'\n' in buf:
        cmd, buf = buf.split(b'\n', 1)
        if cmd == b'press':
            ev(1, 0x130, 1); ev(0, 0, 0); time.sleep(0.1); ev(1, 0x130, 0); ev(0, 0, 0)
PY
  bg pad python3 $D/pad.py "$PADNAME"
  waitfor 10 grep -q "$PADNAME" /proc/bus/input/devices || fail "pad: device did not appear (see $LOG)"
  H=$(awk -v RS= -v n="$PADNAME" 'index($0, n) {print}' /proc/bus/input/devices | grep '^H:')
  EV=$(echo "$H" | grep -o 'event[0-9]*' | head -1); JS=$(echo "$H" | grep -o 'js[0-9]*' | head -1)
  echo "$EV" >$D/pad.event
  ok "pad name='$PADNAME' event=$EV js=${JS:-none}" ;;

pad-press) # press A on the pad, read it back from evdev (and from /dev/input/js* when joydev made one)
  EV=$(cat $D/pad.event 2>/dev/null) || skip "pad-press: no pad-up"
  python3 - "$EV" <<'PY' || fail "pad-press: no BTN_SOUTH press read back"
import os, select, struct, sys, time
ev = os.open('/dev/input/' + sys.argv[1], os.O_RDONLY | os.O_NONBLOCK)
js = None
for n in sorted(os.listdir('/dev/input')):
    if n.startswith('js') and open('/sys/class/input/%s/device/name' % n).read().strip() == 'Microsoft X-Box 360 pad':
        js = os.open('/dev/input/' + n, os.O_RDONLY | os.O_NONBLOCK)
os.write(os.open('/run/hwsim/pad.fifo', os.O_WRONLY), b'press\n')
got_ev = got_js = False; end = time.time() + 5
while time.time() < end and not (got_ev and (got_js or js is None)):
    r, _, _ = select.select([f for f in (ev, js) if f is not None], [], [], 0.5)
    if ev in r:
        for i in range(0, len(d := os.read(ev, 24 * 16)), 24):
            _, _, t, c, v = struct.unpack('llHHi', d[i:i + 24]); got_ev |= (t, c, v) == (1, 0x130, 1)
    if js is not None and js in r:
        for i in range(0, len(d := os.read(js, 8 * 16)), 8):
            _, v, t, n = struct.unpack('IhBB', d[i:i + 8]); got_js |= (t, n, v) == (1, 0, 1)  # 0x81 init events are not 1
sys.exit(0 if got_ev and (got_js or js is None) else 1)
PY
  ok "pad-press BTN_SOUTH=1 read back from $EV$([ -n "$(ls /dev/input/js* 2>/dev/null)" ] && echo ' and js')" ;;

brightness) # cannot be faked: sysfs backlight devices are made only by drivers; report what the DDC path has
  modprobe i2c-dev 2>/dev/null
  BL=$(ls /sys/class/backlight 2>/dev/null | wc -l)
  LIB=no; ldconfig -p | grep -q libddcutil && LIB=yes
  CLI=no; command -v ddcutil >/dev/null && CLI=yes
  echo "INFO brightness backlight-devices=$BL libddcutil=$LIB ddcutil-cli=$CLI i2c-dev=$(lsmod | grep -c '^i2c_dev') i2c-nodes=$(ls /dev/i2c-* 2>/dev/null | wc -l) (VM has no panel or DDC monitor)"
  [ "$LIB" = yes ] && exit 0 || exit 3 ;;

teardown)
  for p in $D/*.pid; do [ -e "$p" ] && kill "$(cat "$p")" 2>/dev/null; done
  nmcli connection delete $SSID >/dev/null 2>&1
  lpadmin -x MountainTest >/dev/null 2>&1
  pkill -x hostapd; pkill -x ippeveprinter
  sleep 1
  rmmod v4l2loopback mac80211_hwsim hci_vhci uinput >/dev/null 2>&1
  ok "teardown" ;;

*) echo "usage: $0 setup|wifi-up|wifi-join|wifi-leave|bt-up|bt-pair|cam-up|printer-up|printer-print|pad-up|pad-press|brightness|teardown"; exit 2 ;;
esac
