import QtQuick
import QtQuick.Layouts

// Your info and Sign-in options: who is signed in, and Change password (passwd in a terminal window).
ColumnLayout {
    id: ac
    spacing: 10
    property string full: ""
    property string user: ""
    Component.onCompleted: app.sh("echo \"$(getent passwd \"$(id -un)\" | cut -d: -f5 | cut -d, -f1)\"; id -un", out => {
        const l = out.split("\n");
        full = l[0];
        user = l[1] || l[0];
    })

    PageTitle { title: "Your account" }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        SettingRow { text: ac.full || ac.user; description: "Local account · " + ac.user; iconName: "user-identity"; chevron: false }
        SettingRow {
            text: "Change your password"
            description: "Opens a window where you type the old and new password"
            iconName: "preferences-desktop-user-password"
            divider: true
            onClicked: app.run("konsole -e passwd")
        }
    }
}
