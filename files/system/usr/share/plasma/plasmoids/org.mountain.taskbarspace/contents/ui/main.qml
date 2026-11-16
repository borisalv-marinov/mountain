// Empty taskbar space (replaces Plasma's panel spacer). Right-click: Windows' taskbar menu, "Task Manager" and "Taskbar settings",
// instead of Plasma's "Add Widgets / Show Panel Configuration" (that menu is compiled into Plasma, so it can't be changed).
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    readonly property bool expanding: Plasmoid.configuration.expanding
    readonly property int length: Plasmoid.configuration.length

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    function run(cmd) { exec.connectSource("setsid -f " + cmd + " >/dev/null 2>&1"); }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: source => disconnectSource(source)
    }

    fullRepresentation: MouseArea {
        id: area
        Layout.fillWidth: root.expanding
        Layout.fillHeight: true
        Layout.minimumWidth: root.expanding ? 1 : root.length
        Layout.preferredWidth: root.expanding ? 1 : root.length
        Layout.maximumWidth: root.expanding ? Number.POSITIVE_INFINITY : root.length
        acceptedButtons: Qt.RightButton
        onPressed: mouse => { menu.open(mouse.x, mouse.y); mouse.accepted = true; }

        PlasmaExtras.Menu {
            id: menu
            visualParent: area
            PlasmaExtras.MenuItem {
                // Mountain: Task Manager
                text: i18n("Task Manager")
                icon: "utilities-system-monitor"
                onClicked: root.run("plasma-systemmonitor")
            }
            PlasmaExtras.MenuItem { separator: true }
            PlasmaExtras.MenuItem {
                text: i18n("Taskbar settings")
                icon: "configure"
                onClicked: root.run("/usr/libexec/mountain-settings-open personalization")
            }
        }
    }
}
