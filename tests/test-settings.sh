#!/usr/bin/env bash
# v7.6 Settings fixes, checked in the QML source (no image needed).
set -uo pipefail
cd "$(dirname "$0")/.."
U=files/system/usr/share/plasma/plasmoids/org.mountain.settings/contents/ui
Q=files/system/usr/share/plasma/plasmoids/org.mountain.quicksettings/contents/ui
rc=0
t() { if ! grep -qE -- "$2" "$3"; then echo "FAIL $1"; rc=1; fi; }
n() { if grep -qE -- "$2" "$3"; then echo "FAIL $1"; rc=1; fi; }
t "Data usage row is clipped to its card" 'Layout.maximumWidth: parent' $U/NetworkPage.qml
n "no 'Updates are manual' wording" 'Updates are manual' $U/main.qml
n "no 'Updates are manual' wording (Home)" 'Updates are manual' $U/HomePage.qml
t "updates text says they download by themselves" 'download by themselves' $U/main.qml
t "Night light is a System item" 'page: "nightlight"' $U/main.qml
n "Night light not on the Accessibility page" 'nightlight' $U/AccessibilityPage.qml
awk '/id: "accessibility", name/,/id: "privacy"/' $U/main.qml | grep -q nightlight && { echo "FAIL Night light still in Accessibility list"; rc=1; }
awk '/id: "system", name/,/id: "devices"/' $U/main.qml | grep -q 'page: "nightlight"' || { echo "FAIL Night light not under System"; rc=1; }
awk '/id: "time", name/,/id: "gaming"/' $U/main.qml | grep -q 'page: "typing"' || { echo "FAIL Typing not under Time & language"; rc=1; }
awk '/id: "devices", name/,/id: "network"/' $U/main.qml | grep -q 'page: "typing"' && { echo "FAIL Typing still under Bluetooth & devices"; rc=1; }
t "About reads the build from /usr/lib/os-release" 'usr/lib/os-release' $U/AboutPage.qml
n "About does not show PRETTY_NAME (Bazzite)" 'PRETTY_NAME' $U/AboutPage.qml
t "Accounts has Other users (kcm_users)" 'systemsettings kcm_users' $U/AccountPage.qml
t "card subtitles wrap, not clip" 'wrapMode: Text.WordWrap' $U/CardHeader.qml
t "quick-settings tile labels wrap" 'wrapMode: Text.WordWrap' $Q/Tile.qml
n "quick-settings tile labels do not elide" 'elide:' $Q/Tile.qml
[ $rc = 0 ] && echo "test-settings: ok"
exit $rc
