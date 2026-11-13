#!/usr/bin/env bash
# "Hello, <name>" above the password box on the login screen (Plasma Login Manager) and the lock screen.
# Both build their sign-in from KDE's shared QML module org.kde.breeze.components. Its qmldir "prefer"s the copy
# compiled into the plugin, so drop that line to make Qt load the files on disk, then patch UserDelegate.qml.
# Fails loudly if KDE's files change shape. The lock screen has kscreenlocker's built-in fallback if QML breaks.
set -euo pipefail
d=$(find /usr/lib64/qt6/qml /usr/lib/qt6/qml -type d -path '*/org/kde/breeze/components' -print -quit 2>/dev/null || true)
[[ -n $d && -f $d/qmldir && -f $d/UserDelegate.qml ]] || { echo "lock-screen: breeze components not found"; exit 1; }
sed -i '/^prefer /d' "$d/qmldir"
python3 - "$d/UserDelegate.qml" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = '        text: wrapper.name\n'
new = '        text: wrapper.isCurrent && wrapper.name ? "Hello, " + wrapper.name : wrapper.name // Mountain: Windows-style greeting\n'
assert s.count(old) == 1, f'UserDelegate.qml: expected 1 "text: wrapper.name", got {s.count(old)}'
open(p, 'w', encoding='utf-8', newline='').write(s.replace(old, new))
PY
# Windows-style clock and wrong password, in the same shared module (both screens): one clock format (a greeter
# without a locale gets US English, like the taskbar: "3:43 AM", "Friday, November 13"), and a failed sign-in shows
# "The password is incorrect. Try again." with an OK button in place of the password box until OK or a key press.
python3 - "$d" <<'PY'
import sys
d = sys.argv[1]
def patch(name, pairs):
    p = f'{d}/{name}'; s = open(p, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, f'{name}: expected 1 of {old!r}, got {s.count(old)}'
        s = s.replace(old, new)
    open(p, 'w', encoding='utf-8', newline='').write(s)
patch('Clock.qml', [
    ('    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software\n',
     '    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software\n'
     '    readonly property var mtLocale: Qt.locale().name === "C" ? Qt.locale("en_US") : Qt.locale() // Mountain: no locale = US English\n'),
    ('text: Qt.formatTime(timeSource.dateTime, Qt.locale(), Locale.ShortFormat)',
     'text: Qt.formatTime(timeSource.dateTime, root.mtLocale, Locale.ShortFormat)'),
    ('text: Qt.formatDate(timeSource.dateTime, Qt.locale(), Locale.LongFormat)',
     'text: Qt.formatDate(timeSource.dateTime, root.mtLocale, root.mtLocale.dateFormat(Locale.LongFormat).replace(/[,.]? *y+[.年]?/, "")) // Mountain: no year, as Windows'),
    ('trackSeconds: Qt.locale().timeFormat(Locale.ShortFormat)', 'trackSeconds: root.mtLocale.timeFormat(Locale.ShortFormat)'),
])
patch('SessionManagementScreen.qml', [
    ('    property real fontSize: Kirigami.Theme.defaultFont.pointSize + 2\n',
     '''    property real fontSize: Kirigami.Theme.defaultFont.pointSize + 2

    // Mountain: Windows-style wrong password. Latched on the screens' own (translated) failure text, so the 3 s
    // auto-clear of that text does not hide it; OK, Enter, a click on the user or the first typed key dismisses it.
    property bool mtWrongPassword: false
    property Item mtLastFocus: null
    function mtIsFailure(t) {
        return [i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:status", "Unlocking failed"),
                i18nd("plasma_login", "Login Failed"), i18nd("plasma-desktop-sddm-theme", "Login Failed")]
            .some(m => m && t.includes(m));
    }
    function mtShowWrong() {
        mtWrongPassword = true;
        Qt.callLater(() => { // after the screens refocus their password box
            const f = root.Window.activeFocusItem;
            if (f && f !== mtOk) mtLastFocus = f;
            mtOk.forceActiveFocus();
        });
    }
    function mtDismiss(ch) {
        mtWrongPassword = false;
        const f = mtLastFocus;
        if (!f) return;
        f.forceActiveFocus();
        if (ch && f.insert) {
            if (f.selectedText) f.remove(f.selectionStart, f.selectionEnd);
            f.insert(f.cursorPosition, ch);
        }
    }
    onUserSelected: mtWrongPassword = false
'''),
    ('        bounceAnimation.start();\n',
     '        bounceAnimation.start();\n        if (mtIsFailure(notificationsLabel.text)) mtShowWrong(); // Mountain: the same failure again\n'),
    ('            font.italic: true\n',
     '            font.italic: true\n            visible: !root.mtWrongPassword\n            onTextChanged: if (root.mtIsFailure(text)) root.mtShowWrong()\n'),
    ('                id: innerLayout\n', '                id: innerLayout\n                visible: !root.mtWrongPassword\n'),
    ('        ColumnLayout {\n            Layout.minimumHeight: implicitHeight\n',
     '''        ColumnLayout { // Mountain: wrong password message
            visible: root.mtWrongPassword
            Layout.maximumWidth: Kirigami.Units.gridUnit * 16
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing
            PlasmaComponents3.Label {
                text: "The password is incorrect. Try again."
                font.pointSize: root.fontSize
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                Accessible.role: Accessible.AlertMessage
            }
            PlasmaComponents3.Button {
                id: mtOk
                text: "OK"
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                onClicked: root.mtDismiss("")
                Keys.onReturnPressed: clicked()
                Keys.onEnterPressed: clicked()
                Keys.onPressed: event => { // typing again goes straight into the password box
                    if (event.text.length === 1 && event.text.charCodeAt(0) > 32) {
                        root.mtDismiss(event.text);
                        event.accepted = true;
                    }
                }
            }
        }
        ColumnLayout {
            Layout.minimumHeight: implicitHeight
'''),
])
PY
grep -q '"Hello, "' "$d/UserDelegate.qml"
grep -q 'The password is incorrect. Try again.' "$d/SessionManagementScreen.qml"
grep -q 'mtLocale' "$d/Clock.qml"
! grep -q '^prefer ' "$d/qmldir"
# the sign-in screen runs with the system locale: without one Qt shows 24 h and day-first dates (the installer's choice still wins)
[[ -s /etc/locale.conf ]] || echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo "lock-screen: greeting patched in $d"
