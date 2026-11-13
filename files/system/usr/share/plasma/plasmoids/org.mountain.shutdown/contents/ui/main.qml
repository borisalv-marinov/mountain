/*
    Shut Down Mountain (Alt+F4 on the desktop), like Windows' "Shut Down Windows" box:
    "What do you want the computer to do?" with Switch user / Sign out / Sleep / Restart / Shut down, OK / Cancel.
    Started by the mountain-altf4 KWin script through mountain-shutdown-dialog.service (plasmawindowed org.mountain.shutdown).
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.sessions

PlasmoidItem {
    id: app
    property bool windowsBoot: false
    readonly property string bootCmd: "/usr/libexec/mountain-windows-boot check"

    SessionManagement { id: session }
    // OK does it at once, like Windows (0 = SessionManagement.Skip: no second countdown screen)
    readonly property var choices: [
        { t: "Switch user", d: "Keeps your apps open and lets someone else sign in.", act: () => session.switchUser(), hidden: !session.canSwitchUser },
        { t: "Sign out", d: "Closes all apps and signs you out.", act: () => session.requestLogout(0) },
        { t: "Sleep", d: "The PC stays on but uses low power. Apps stay open so you can get right back to where you left off.", act: () => session.suspend(), hidden: !session.canSuspend },
        { t: "Restart", d: "Closes all apps, turns off the PC, and then turns it on again.", act: () => session.requestReboot(0) },
        { t: "Shut down", d: "Closes all apps and turns off the PC.", act: () => session.requestShutdown(0) },
        { t: "Restart into Windows", d: "Restarts the PC into Windows once. Next time it starts Mountain again.", cmd: "/usr/libexec/mountain-windows-boot go", hidden: !windowsBoot }
    ].filter(c => !c.hidden)

    readonly property var hostWindow: Window.window
    onHostWindowChanged: if (hostWindow) { hostWindow.title = "Shut Down Mountain"; hostWindow.color = "transparent"; hostWindow.width = 440; hostWindow.height = 236; }
    Connections {
        target: app.hostWindow
        function onVisibleChanged() { if (app.hostWindow.visible) app.pickDefault(); }
    }
    preferredRepresentation: fullRepresentation

    function close() { if (hostWindow) hostWindow.close(); }
    function pickDefault() { if (box) box.currentIndex = choices.findIndex(c => c.t === "Shut down"); }
    property var box: null
    function ok() {
        const c = choices[box.currentIndex];
        if (!c) return;
        if (c.cmd) { pending = "setsid -f " + c.cmd + " >/dev/null 2>&1"; exec.connectSource(pending); } // asks for the password, then restarts
        else { c.act(); closeSoon.start(); }
    }
    property string pending: ""
    // close once the request is out: plasmawindowed quits with its last window and would take a half-sent request with it
    Timer { id: closeSoon; interval: 250; onTriggered: app.close() }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: [app.bootCmd]
        onNewData: (source, data) => {
            if (source === app.bootCmd) { app.windowsBoot = data["exit code"] === 0; app.pickDefault(); }
            else if (source === app.pending) { app.pending = ""; app.close(); }
            disconnectSource(source);
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
        Layout.minimumWidth: 440
        Layout.minimumHeight: 236
        Layout.preferredWidth: 440
        Layout.preferredHeight: 236
        radius: 8
        color: Qt.rgba(0.086, 0.09, 0.11, 0.97)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        Accessible.role: Accessible.Dialog
        Accessible.name: "Shut Down Mountain"
        Keys.onEscapePressed: app.close()

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 8; rightMargin: 8; topMargin: 1 }
            height: 1
            color: Qt.rgba(1, 1, 1, 0.14)
        }

        ColumnLayout {
            anchors { fill: parent; margins: 14 }
            spacing: 10

            RowLayout { // title bar
                spacing: 8
                Kirigami.Icon { source: "system-shutdown"; implicitWidth: 16; implicitHeight: 16 }
                Text { text: "Shut Down Mountain"; color: "#F2F3F5"; font: Kirigami.Theme.defaultFont; Layout.fillWidth: true }
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
                spacing: 14
                Layout.topMargin: 4
                Kirigami.Icon { source: "system-shutdown"; implicitWidth: 40; implicitHeight: 40; Layout.alignment: Qt.AlignTop }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: "What do you want the computer to do?"; color: "#F2F3F5"; font: Kirigami.Theme.defaultFont }
                    QQC2.ComboBox {
                        id: combo
                        Layout.fillWidth: true
                        model: app.choices.map(c => c.t)
                        Accessible.name: "What do you want the computer to do?"
                        Accessible.description: app.choices[currentIndex] ? app.choices[currentIndex].d : ""
                        Component.onCompleted: { app.box = combo; app.pickDefault(); forceActiveFocus(); }
                        onModelChanged: app.pickDefault()
                        Keys.onReturnPressed: if (!popup.visible) app.ok()
                        Keys.onEnterPressed: if (!popup.visible) app.ok()
                        Keys.onEscapePressed: if (popup.visible) popup.close(); else app.close()
                        background: Rectangle {
                            radius: 6
                            color: combo.hovered ? "#202227" : "#16171C"
                            border.width: combo.activeFocus ? 2 : 1
                            border.color: combo.activeFocus ? "#5AB0FF" : Qt.rgba(1, 1, 1, 0.16)
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: app.choices[combo.currentIndex] ? app.choices[combo.currentIndex].d : ""
                        color: "#A4A9B2"
                        wrapMode: Text.WordWrap
                        font: Kirigami.Theme.smallFont
                    }
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                GlassButton { text: "OK"; highlighted: true; onClicked: app.ok() }
                GlassButton { text: "Cancel"; onClicked: app.close() }
            }
        }
    }
}
