// Mountain Task Manager list: one face, four tabs (Startup apps, Users, Services, device names).
// Rows come from `/usr/libexec/mountain-taskmanager <mode>` as tab-separated lines: a header line, then rows whose first field is an id.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.faces as Faces
import org.kde.plasma.plasma5support as P5Support

Faces.SensorFace {
    id: root

    readonly property string mode: controller.faceConfiguration.mode || "device"
    readonly property string helper: "/usr/libexec/mountain-taskmanager"
    readonly property string listCmd: helper + " " + mode
    readonly property bool actions: mode === "startup" || mode === "services"
    property var header: []
    property var rows: []
    property bool busy: false
    property string filter: ""

    Layout.minimumHeight: mode === "device" ? Kirigami.Units.gridUnit * 6 : Kirigami.Units.gridUnit * 10
    Layout.minimumWidth: Kirigami.Units.gridUnit * 12

    function quote(s) {
        return "'" + String(s).split("'").join("'\\''") + "'";
    }
    function refresh() {
        exec.connectSource(listCmd);
    }
    function act(args) {
        busy = true;
        exec.connectSource(helper + " " + args + " # " + Date.now()); // unique source, so the same action can run twice
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            if (source === root.listCmd) {
                const lines = (data["stdout"] || "").split("\n").filter(l => l !== "");
                root.header = lines.length > 0 ? lines[0].split("\t") : [];
                root.rows = lines.slice(1).map(l => l.split("\t"));
            } else {
                root.busy = false;
                root.refresh();
            }
        }
    }

    // live tabs refresh while shown; Startup apps and device names only change when you act
    Timer {
        interval: root.mode === "services" ? 5000 : 3000
        repeat: true
        running: root.visible && (root.mode === "users" || root.mode === "services")
        onTriggered: root.refresh()
    }
    Component.onCompleted: refresh()

    contentItem: ColumnLayout {
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            Kirigami.Heading {
                level: 2
                text: root.controller.title
                Layout.fillWidth: true
            }
            Kirigami.SearchField {
                visible: root.mode === "services"
                onTextChanged: root.filter = text.toLowerCase()
            }
            QQC2.BusyIndicator {
                running: root.busy
                visible: running
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            visible: root.actions
            wrapMode: Text.WordWrap
            text: root.mode === "startup" ? "These apps start when you sign in. A change takes effect at your next sign-in."
                                          : "Starting or stopping a service asks for the administrator password."
        }

        // column header (device names have none)
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            visible: root.mode !== "device"
            spacing: Kirigami.Units.largeSpacing
            Repeater {
                model: root.header.slice(1)
                QQC2.Label {
                    required property string modelData
                    required property int index
                    text: modelData
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: index === 0 || (root.mode === "services" && index === 1)
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                }
            }
            Item {
                visible: root.actions
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
            }
        }
        Kirigami.Separator {
            Layout.fillWidth: true
            visible: root.mode !== "device"
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: contentHeight
            clip: true
            model: root.filter === "" ? root.rows : root.rows.filter(r => r.join(" ").toLowerCase().indexOf(root.filter) >= 0)
            QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
            delegate: QQC2.ItemDelegate {
                id: line
                required property var modelData
                required property int index
                width: ListView.view.width
                highlighted: ListView.isCurrentItem
                onClicked: list.currentIndex = index
                Accessible.name: modelData.slice(1).join(", ")
                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing
                    Repeater {
                        model: line.modelData.slice(1)
                        QQC2.Label {
                            required property string modelData
                            required property int index
                            text: modelData
                            elide: Text.ElideRight
                            font.bold: root.mode === "device" && index === 0
                            Layout.fillWidth: root.mode === "device" ? index === 1 : (index === 0 || (root.mode === "services" && index === 1))
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                        }
                    }
                    // Startup apps: Enable/Disable. Services: Start, or Stop and Restart.
                    RowLayout {
                        id: buttons
                        visible: root.actions
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                        readonly property bool on: root.mode === "startup" ? line.modelData[2] === "Enabled" : line.modelData[3] === "Running"
                        QQC2.Button {
                            text: root.mode === "startup" ? (buttons.on ? "Disable" : "Enable") : (buttons.on ? "Stop" : "Start")
                            enabled: !root.busy
                            onClicked: root.act(root.mode === "startup"
                                ? "startup-set " + root.quote(line.modelData[0]) + (buttons.on ? " off" : " on")
                                : "service " + (buttons.on ? "stop " : "start ") + root.quote(line.modelData[0]))
                        }
                        QQC2.Button {
                            visible: root.mode === "services" && buttons.on
                            text: "Restart"
                            enabled: !root.busy
                            onClicked: root.act("service restart " + root.quote(line.modelData[0]))
                        }
                    }
                }
            }
        }
    }
}
