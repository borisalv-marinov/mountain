import QtQuick
import QtQuick.Layouts

// Lock screen: kscreenlockerrc [Daemon] Autolock, Timeout (minutes) and LockOnResume (--notify makes the running lock service re-read it).
ColumnLayout {
    id: lk
    spacing: 10
    property bool auto: true
    property int minutes: 5
    property bool onWake: true
    readonly property var times: [0, 1, 2, 5, 10, 15, 30, 60]
    readonly property var names: [i18n("Never"), i18n("1 minute"), i18n("2 minutes"), i18n("5 minutes"), i18n("10 minutes"), i18n("15 minutes"), i18n("30 minutes"), i18n("1 hour")]
    readonly property string rc: "kwriteconfig6 --file kscreenlockerrc --notify --group Daemon --key "
    readonly property string rd: "kreadconfig6 --file kscreenlockerrc --group Daemon --key "

    function load() {
        app.sh(rd + "Autolock --default true; " + rd + "Timeout --default 5; " + rd + "LockOnResume --default true # " + Date.now(), out => {
            const l = out.split("\n");
            auto = l[0] !== "false";
            minutes = +l[1];
            onWake = l[2] !== "false";
        });
    }
    function setAfter(m) { // m is one of our own numbers
        app.sh(rc + "Autolock --type bool " + (m > 0) + (m > 0 ? " && " + rc + "Timeout " + m : "") + " # " + Date.now(), load);
    }
    function flipWake() { app.sh(rc + "LockOnResume --type bool " + (onWake ? "false" : "true") + " # " + Date.now(), load); }
    Component.onCompleted: load()

    PageTitle { title: i18n("Lock screen") }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        CardHeader { title: i18n("Lock screen"); subtitle: i18n("Keeps other people out when you step away") }
        ChoiceRow {
            label: i18n("Lock my screen after")
            model: lk.names
            currentIndex: lk.auto ? lk.times.indexOf(lk.minutes) : 0
            onPicked: i => lk.setAfter(lk.times[i])
        }
        SettingRow {
            text: i18n("Ask for my password when the PC wakes up")
            description: i18n("After sleep, the lock screen asks for your password")
            iconName: "system-lock-screen"
            chevron: false
            divider: true
            onClicked: lk.flipWake()
            trailing: PillSwitch { text: i18n("Ask for my password when the PC wakes up"); checked: lk.onWake; onClicked: lk.flipWake() }
        }
    }
}
