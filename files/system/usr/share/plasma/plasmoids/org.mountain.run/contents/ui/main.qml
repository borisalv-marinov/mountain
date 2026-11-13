/*
    Run (Win+R), like Windows: bottom left, "Open:" with earlier entries, OK / Cancel / Browse...
    Run with `plasmawindowed org.mountain.run`; KWin (mountain-altf4 script) removes the frame and places it.
    /usr/libexec/mountain-run decides what the text is (program, app, folder, file, internet address) and opens it.
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: app
    readonly property string helper: "/usr/libexec/mountain-run"
    readonly property string historyCmd: helper + " --history"
    property var history: []
    property string error: ""
    property string pending: ""
    property var box: null // the Open: box (ids inside fullRepresentation are not visible up here)

    readonly property var hostWindow: Window.window
    onHostWindowChanged: if (hostWindow) { hostWindow.title = "Run"; hostWindow.color = "transparent"; hostWindow.width = 420; hostWindow.height = 218; }
    Connections { // plasmawindowed keeps one window per applet: start fresh each time it is shown
        target: app.hostWindow
        function onVisibleChanged() { if (app.hostWindow.visible) app.reset(); }
    }
    preferredRepresentation: fullRepresentation

    function quote(s) { return "'" + s.replace(/'/g, "'\\''") + "'"; }
    function close() { if (hostWindow) hostWindow.close(); }
    function reset() { error = ""; exec.connectSource(historyCmd); }
    function open() {
        if (!box) return;
        const t = box.editText.trim();
        if (t === "" || pending !== "") return;
        error = "";
        pending = helper + " " + quote(t);
        exec.connectSource(pending);
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source, data) => {
            if (source === app.historyCmd) {
                app.history = data.stdout.split("\n").filter(l => l !== "");
                if (app.box && app.history.length) { app.box.editText = app.history[0]; app.box.selectText(); } // last entry, selected, like Windows
            } else if (source === app.pending) {
                app.pending = "";
                if (data["exit code"] === 0) app.close(); else app.error = data.stdout.trim() || "That didn't open. Check the name and try again.";
            }
            disconnectSource(source);
        }
    }

    FileDialog {
        id: browse
        title: "Browse"
        onAccepted: {
            const p = decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, ""));
            if (!app.box) return;
            app.box.editText = p.indexOf(" ") >= 0 ? "\"" + p + "\"" : p;
            app.box.forceActiveFocus();
        }
    }

    component GlassButton: QQC2.AbstractButton {
        id: btn
        property bool highlighted: false
        hoverEnabled: true
        activeFocusOnTab: true
        implicitWidth: Math.max(88, label.implicitWidth + 28)
        implicitHeight: 32
        Accessible.role: Accessible.Button
        Accessible.name: text
        Keys.onReturnPressed: clicked()
        Keys.onEnterPressed: clicked()
        opacity: enabled ? 1 : 0.5
        background: Rectangle {
            radius: 6
            border.width: btn.activeFocus ? 2 : 1
            border.color: btn.activeFocus ? "#5AB0FF" : Qt.rgba(1, 1, 1, 0.14)
            color: btn.highlighted ? (btn.pressed ? "#0063B1" : btn.hovered ? "#1A86D9" : "#0078D4")
                                   : (btn.pressed ? "#101114" : btn.hovered ? "#2A2D33" : "#202227")
        }
        contentItem: Text {
            id: label
            text: btn.text
            color: "#F2F3F5"
            font: Kirigami.Theme.defaultFont
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    fullRepresentation: Rectangle {
        id: shell
        Layout.minimumWidth: 420
        Layout.minimumHeight: 218
        Layout.preferredWidth: 420
        Layout.preferredHeight: 218
        radius: 8
        color: Qt.rgba(0.086, 0.09, 0.11, 0.97)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        Accessible.role: Accessible.Dialog
        Accessible.name: "Run"
        focus: true
        Keys.onEscapePressed: app.close()

        Rectangle { // top highlight of the glass
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 8; rightMargin: 8; topMargin: 1 }
            height: 1
            color: Qt.rgba(1, 1, 1, 0.14)
        }

        ColumnLayout {
            anchors { fill: parent; margins: 14 }
            spacing: 10

            RowLayout { // title bar
                spacing: 8
                Kirigami.Icon { source: "system-run"; implicitWidth: 16; implicitHeight: 16 }
                Text { text: "Run"; color: "#F2F3F5"; font: Kirigami.Theme.defaultFont; Layout.fillWidth: true }
                QQC2.AbstractButton {
                    id: closeBtn
                    implicitWidth: 32; implicitHeight: 24
                    hoverEnabled: true
                    activeFocusOnTab: false
                    Accessible.role: Accessible.Button
                    Accessible.name: "Close"
                    onClicked: app.close()
                    background: Rectangle { radius: 4; color: closeBtn.hovered ? "#C42B1C" : "transparent" }
                    contentItem: Kirigami.Icon { source: "window-close-symbolic"; implicitWidth: 14; implicitHeight: 14; color: "#F2F3F5" }
                }
            }

            RowLayout {
                spacing: 12
                Kirigami.Icon { source: "system-run"; implicitWidth: 32; implicitHeight: 32; Layout.alignment: Qt.AlignTop }
                Text {
                    Layout.fillWidth: true
                    text: "Type the name of a program, folder, document, or internet resource, and Mountain will open it for you."
                    wrapMode: Text.WordWrap
                    color: "#F2F3F5"
                    font: Kirigami.Theme.defaultFont
                }
            }

            RowLayout {
                spacing: 10
                Text { text: "Open:"; color: "#F2F3F5"; font: Kirigami.Theme.defaultFont }
                QQC2.ComboBox {
                    id: field
                    Layout.fillWidth: true
                    editable: true
                    model: app.history
                    focus: true
                    Accessible.name: "Open"
                    Accessible.description: app.error
                    Component.onCompleted: { app.box = field; forceActiveFocus(); app.reset(); }
                    onAccepted: app.open()
                    onEditTextChanged: app.error = ""
                    Keys.onEscapePressed: app.close()
                    function selectText() { if (contentItem && contentItem.selectAll) contentItem.selectAll(); }
                    background: Rectangle {
                        radius: 6
                        color: "#0B0C0F"
                        border.width: field.activeFocus ? 2 : 1
                        border.color: app.error !== "" ? "#FF99A4" : field.activeFocus ? "#5AB0FF" : Qt.rgba(1, 1, 1, 0.16)
                    }
                }
            }

            Text { // errors inline, under the box (Windows opens a second box for these)
                Layout.fillWidth: true
                Layout.leftMargin: 46
                text: app.error
                visible: text !== ""
                color: "#FF99A4"
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font: Kirigami.Theme.smallFont
                Accessible.role: Accessible.AlertMessage
                Accessible.name: text
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                GlassButton { text: "OK"; highlighted: true; enabled: field.editText.trim() !== "" && app.pending === ""; onClicked: app.open() }
                GlassButton { text: "Cancel"; onClicked: app.close() }
                GlassButton { text: "Browse..."; onClicked: browse.open() }
            }
        }
    }
}
