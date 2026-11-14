import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Notifications: Do not disturb and lock-screen notifications in plasmanotifyrc (--notify reaches plasma's notification service).
// Per-app notification settings are not here (skipped).
ColumnLayout {
    id: np
    spacing: 10
    property bool dnd: false
    property bool lockScreen: true
    readonly property string rc: "kwriteconfig6 --file plasmanotifyrc --notify "

    function load() {
        app.sh("kreadconfig6 --file plasmanotifyrc --group DoNotDisturb --key Until; kreadconfig6 --file plasmanotifyrc --group Notifications --key ShowOnLockscreen --default true # " + Date.now(), out => {
            const l = out.split("\n");
            dnd = l[0] !== "" && l[0] > new Date().toISOString(); // an ISO date later than now
            lockScreen = l[1] !== "false";
        });
    }
    function toggleDnd() {
        app.sh(dnd ? "kwriteconfig6 --file plasmanotifyrc --group DoNotDisturb --key Until --delete --notify # " + Date.now()
                   : rc + "--group DoNotDisturb --key Until 2099-01-01T00:00:00 # " + Date.now(), load);
    }
    function toggleLock() { app.sh(rc + "--group Notifications --key ShowOnLockscreen --type bool " + (lockScreen ? "false" : "true") + " # " + Date.now(), load); }
    Component.onCompleted: load()

    PageTitle { title: "Notifications" }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        SettingRow {
            text: "Do not disturb"
            description: "Silence pop-ups until you turn this off"
            iconName: "notifications-disabled"
            chevron: false
            onClicked: np.toggleDnd()
            trailing: PillSwitch { text: "Do not disturb"; checked: np.dnd; onClicked: np.toggleDnd() }
        }
        SettingRow {
            text: "Show notifications on the lock screen"
            description: "Other people near your PC could read them"
            iconName: "system-lock-screen"
            chevron: false
            divider: true
            onClicked: np.toggleLock()
            trailing: PillSwitch { text: "Show notifications on the lock screen"; checked: np.lockScreen; onClicked: np.toggleLock() }
        }
    }
}
