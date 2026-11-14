import QtQuick
import QtQuick.Layouts

// Startup apps: the same list as Task Manager's Startup tab (mountain-taskmanager-startup); the switch calls `mountain-taskmanager startup-set`.
ColumnLayout {
    id: su
    spacing: 10
    property var apps: [] // [{ id, name, on }]
    readonly property string helper: "/usr/libexec/mountain-taskmanager"

    function load() {
        app.sh("/usr/libexec/mountain-taskmanager-startup # " + Date.now(), out => {
            apps = out.split("\n").slice(1).filter(r => r !== "").map(r => { const f = r.split("\t"); return { id: f[0], name: f[1], on: f[3] === "Enabled" }; });
        });
    }
    function flip(a) { // the id is a file name: single-quote it so no character can end the argument
        app.sh(helper + " startup-set '" + a.id.split("'").join("'\\''") + "' " + (a.on ? "off" : "on") + " # " + Date.now(), load);
    }
    Component.onCompleted: load()

    PageTitle { title: "Startup apps" }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        CardHeader { title: "Apps that start when you sign in"; subtitle: "Turn off the ones you do not need" }
        GText { visible: su.apps.length === 0; Layout.margins: 18; text: "No startup apps."; dim: true }
        Repeater {
            model: su.apps
            delegate: SettingRow {
                required property var modelData
                required property int index
                text: modelData.name
                chevron: false
                divider: index > 0
                onClicked: su.flip(modelData)
                trailing: [
                    GText { text: modelData.on ? "On" : "Off" },
                    PillSwitch { text: modelData.name; checked: modelData.on; onClicked: su.flip(modelData) }
                ]
            }
        }
    }
}
