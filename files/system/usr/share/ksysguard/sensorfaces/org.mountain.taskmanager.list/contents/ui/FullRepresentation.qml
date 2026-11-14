// Mountain Task Manager list: one face, five tabs (Background processes, Startup apps, Users, Services, device names).
// Rows come from `/usr/libexec/mountain-taskmanager <mode>` (Startup apps: mountain-taskmanager-startup) as tab-separated
// lines: a header line, then rows whose first field is an id.
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
    readonly property string listCmd: mode === "startup" ? "bash " + helper + "-startup" : helper + " " + mode
    readonly property bool actions: mode === "startup" || mode === "services" || mode === "processes"
    property string error: ""
    property var header: []
    property var rows: [] // every row as parsed; rowModel holds the ones the search shows
    property string lastText: ""
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
    // Update rows in place, keyed on the id, so delegates (and the selection, and the button under the pointer)
    // stay with their service or app; new rows go at the end, gone rows are removed.
    function sync() {
        const want = Object.create(null), order = [], seen = Object.create(null);
        for (const r of rows) {
            if (filter !== "" && r.join(" ").toLowerCase().indexOf(filter) < 0)
                continue;
            const key = r[0] + "#" + (seen[r[0]] = (seen[r[0]] || 0) + 1); // device rows share ids (two disks)
            want[key] = r.join("\t");
            order.push(key);
        }
        for (let i = rowModel.count - 1; i >= 0; i--) {
            const key = rowModel.get(i).key;
            if (!(key in want)) {
                rowModel.remove(i);
            } else {
                if (rowModel.get(i).cells !== want[key])
                    rowModel.setProperty(i, "cells", want[key]);
                delete want[key];
            }
        }
        for (const key of order)
            if (key in want)
                rowModel.append({ key: key, cells: want[key] });
    }
    onFilterChanged: {
        rowModel.clear(); // a new search shows its matches in list order
        sync();
    }

    ListModel {
        id: rowModel
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
                const out = data["stdout"] || "";
                if (out === root.lastText)
                    return; // nothing changed: leave the list alone
                root.lastText = out;
                const lines = out.split("\n").filter(l => l !== "");
                const head = lines.length > 0 ? lines[0].split("\t") : [];
                if (head.join("\t") !== root.header.join("\t"))
                    root.header = head;
                root.rows = lines.slice(1).map(l => l.split("\t"));
                root.sync();
            } else {
                root.busy = false;
                root.error = data["exit code"] ? (data["stderr"] || "That did not work.").trim() : "";
                root.refresh();
            }
        }
    }

    // live tabs refresh while shown, but not while the pointer is on the list or an action runs;
    // Startup apps and device names only change when you act
    Timer {
        interval: root.mode === "services" ? 5000 : 3000 // processes: as often as Users
        repeat: true
        running: root.visible && !root.busy && !listHover.hovered && (root.mode === "users" || root.mode === "services" || root.mode === "processes")
        onTriggered: root.refresh()
    }
    Component.onCompleted: refresh()

    // End task asks first: unsaved work in that process is lost
    Kirigami.PromptDialog {
        id: confirm
        property string pid: ""
        property string name: ""
        title: "End " + name + "?"
        subtitle: "If this process has unsaved work, it will be lost."
        standardButtons: Kirigami.Dialog.Cancel
        customFooterActions: [
            Kirigami.Action {
                text: "End task"
                icon.name: "process-stop"
                onTriggered: {
                    root.act("end " + root.quote(confirm.pid));
                    confirm.close();
                }
            }
        ]
    }

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
                visible: root.mode === "services" || root.mode === "processes"
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
            visible: root.mode === "startup" || root.mode === "services"
            wrapMode: Text.WordWrap
            text: root.mode === "startup" ? "These apps start when you sign in. A change takes effect at your next sign-in."
                                          : "Starting or stopping a service asks for the administrator password."
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Error
            showCloseButton: true
            visible: root.error !== ""
            text: root.error
            onVisibleChanged: if (!visible) root.error = ""
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
            model: rowModel
            QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
            HoverHandler {
                id: listHover
            }
            delegate: QQC2.ItemDelegate {
                id: line
                required property string cells
                required property int index
                readonly property var modelData: cells.split("\t")
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
                    // Startup apps: Enable/Disable. Services: Start, or Stop and Restart. Processes: End task.
                    RowLayout {
                        id: buttons
                        visible: root.actions
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                        readonly property bool on: root.mode === "startup" ? line.modelData[3] === "Enabled" : line.modelData[3] === "Running"
                        QQC2.Button {
                            visible: root.mode === "processes"
                            text: "End task"
                            enabled: !root.busy
                            onClicked: {
                                confirm.pid = line.modelData[0];
                                confirm.name = line.modelData[1];
                                confirm.open();
                            }
                        }
                        QQC2.Button {
                            visible: root.mode !== "processes"
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
