#!/usr/bin/env bash
# Tests mountain-user-setup: places file content, valid XML, never overwrites.
S=$(dirname "$0")/../files/system/usr/libexec/mountain-user-setup
T=$(dirname "$0")/../files/system/usr/share/mountain/user-places.xbel.in
H=$(mktemp -d "/tmp/home with space.XXXX"); rc=0
f=$H/.local/share/user-places.xbel
ok() { if eval "$1"; then echo "ok: $2"; else echo "FAIL: $2"; rc=1; fi; }
HOME=$H XDG_DATA_HOME= MOUNTAIN_PLACES_TEMPLATE=$T bash "$S"
ok '[[ -f "$f" ]]' "file written"
ok 'python3 -c "import sys,xml.dom.minidom as m;m.parse(sys.argv[1])" "$f"' "valid XML"
ok 'grep -q "<kde_places_version>4</kde_places_version>" "$f"' "version 4 (no re-seeding)"
ok '! grep -q "Remote-IsHidden" "$f" && grep -q "href=\"remote:/\"" "$f"' "Network shown (remote:/)"
ok 'grep -q "href=\"file://[^\"]*/mountain/This%20PC\"" "$f" && grep -q "<title>This PC</title>" "$f"' "This PC place is the drive-letter folder"
ok 'grep -q "<GroupState-Devices-IsHidden>true</GroupState-Devices-IsHidden>" "$f"' "internal Devices group hidden"
ok '! grep -q "RemovableDevices-IsHidden" "$f"' "USB drives still shown"
ok 'grep -q "href=\"desktop:/\"" "$f"' "Desktop via desktop:/"
ok 'grep -q "href=\"file://[^\"]*with%20space[^\"]*/Documents\"" "$f"' "Documents absolute, space encoded"
ok '[[ $(grep -c "<bookmark " "$f") == 11 ]]' "11 places"
ok '! grep -q "Previous versions" "$f"' "no Previous versions without Btrfs snapshots"
G=$(mktemp -d); HOME=$G XDG_DATA_HOME= MOUNTAIN_SNAPSHOTS_PLACE=1 MOUNTAIN_SNAP_SRC=/var/home MOUNTAIN_PLACES_TEMPLATE=$T bash "$S"
ok 'grep -q "/var/home/.snapshots\"" "$G/.local/share/user-places.xbel" && [[ $(grep -c "<bookmark " "$G/.local/share/user-places.xbel") == 12 ]]' "Previous versions place with snapshots"
rm -rf "$G"
ok '[[ $(eval "$(grep "^esc()" "$S")"; esc "a<b&c>d") == "a&lt;b&amp;c&gt;d" ]]' "XML escaping"
ok '[[ ! -e $H/.config/kwalletrc ]]' "wallet untouched without autologin"
A=$(mktemp); printf '[Autologin]
User=%s
' "$(id -un)" > "$A"
HOME=$H XDG_DATA_HOME= XDG_CONFIG_HOME= MOUNTAIN_AUTOLOGIN_CONF="/nonexistent.conf $A /nonexistent2.conf" MOUNTAIN_PLACES_TEMPLATE=$T bash "$S"
ok 'grep -qx "Enabled=false" "$H/.config/kwalletrc"' "wallet off for an autologin account"
rm -f "$A"
echo edited > "$f"; HOME=$H XDG_DATA_HOME= MOUNTAIN_PLACES_TEMPLATE=$T bash "$S"
ok '[[ $(cat "$f") == edited ]]' "existing file kept"
P=$H/.local/share/plasma-systemmonitor; mkdir -p "$P"; echo '"gpu/all/usage"' > "$P/mountain-2-performance.page"; echo '"cpu/all/usage"' > "$P/mountain-1-processes.page"
HOME=$H XDG_DATA_HOME= MOUNTAIN_PLACES_TEMPLATE=$T bash "$S"
ok '[[ ! -e $P/mountain-2-performance.page && -e $P/mountain-1-processes.page ]]' "an old Task Manager page with the GPU chart is dropped, others kept"
K=$H/skel; D=$H/Desk; mkdir -p "$K/Coding" "$D/Coding"; echo '[Desktop Entry]' > "$K/Coding/Terminal.desktop"; cp "$K/Coding/Terminal.desktop" "$D/Coding/"
echo '[Desktop Entry]' > "$K/Coding/Mine.desktop"; echo '[Desktop Entry]
Exec=evil' > "$D/Coding/Mine.desktop"; echo '[Desktop Entry]' > "$D/Coding/Downloaded.desktop"; chmod -x "$D"/Coding/*
HOME=$H XDG_DATA_HOME= MOUNTAIN_SKEL_DESKTOP=$K MOUNTAIN_DESKTOP_DIR=$D MOUNTAIN_EXPLORER=true MOUNTAIN_PLACES_TEMPLATE=$T bash "$S"
ok '[[ -x $D/Coding/Terminal.desktop && ! -x $D/Coding/Mine.desktop && ! -x $D/Coding/Downloaded.desktop ]]' "shipped launchers are trusted (executable, no open-or-run prompt); edited and downloaded ones are not"
C=$H/.config; mkdir -p "$C/Kvantum"; printf '[General]
theme=BlackGlass
' > "$C/Kvantum/kvantum.kvconfig"; printf '[Layout]
LayoutList=us,bg
VariantList=,phonetic
' > "$C/kxkbrc"; printf '[General]
ViewMode=1
' > "$C/dolphinrc"
HOME=$H XDG_DATA_HOME= XDG_CONFIG_HOME= MOUNTAIN_PLACES_TEMPLATE=$T bash "$S"
ok 'grep -qx "theme=BlackGlassSolid" "$C/Kvantum/kvantum.kvconfig"' "v7.1: an account with see-through app windows gets solid ones"
ok 'grep -qx "VariantList=,bas_phonetic" "$C/kxkbrc"' "v7.1: the old Bulgarian layout becomes Windows' Bulgarian (Phonetic)"
ok '[[ $(sed -n 2p "$C/dolphinrc") == HomeUrl=file://?* ]] && grep -qx "ViewMode=1" "$C/dolphinrc"' "v7.1: File Explorer Home is the real path, in [General], other keys kept"
printf '[General]
theme=KvArc
' > "$C/Kvantum/kvantum.kvconfig"; printf '[General]
HomeUrl=file:///mine
' > "$C/dolphinrc"
HOME=$H XDG_DATA_HOME= XDG_CONFIG_HOME= MOUNTAIN_PLACES_TEMPLATE=$T bash "$S"
ok 'grep -qx "theme=KvArc" "$C/Kvantum/kvantum.kvconfig" && [[ $(grep -c HomeUrl "$C/dolphinrc") == 1 ]] && grep -qx "HomeUrl=file:///mine" "$C/dolphinrc"' "v7.1: a user's own theme and Home are kept"
rm -rf "$H"; exit $rc
