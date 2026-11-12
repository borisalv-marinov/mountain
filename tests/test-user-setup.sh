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
ok 'grep -q "<GroupState-Remote-IsHidden>true</GroupState-Remote-IsHidden>" "$f"' "Network hidden"
ok 'grep -q "<GroupState-Devices-IsHidden>true</GroupState-Devices-IsHidden>" "$f"' "internal Devices group hidden"
ok '! grep -q "RemovableDevices-IsHidden" "$f"' "USB drives still shown"
ok 'grep -q "href=\"desktop:/\"" "$f"' "Desktop via desktop:/"
ok 'grep -q "href=\"file://[^\"]*with%20space[^\"]*/Documents\"" "$f"' "Documents absolute, space encoded"
ok '[[ $(grep -c "<bookmark " "$f") == 8 ]]' "8 places"
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
rm -rf "$H"; exit $rc
