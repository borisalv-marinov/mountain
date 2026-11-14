// Windows 11 show-desktop sliver: an 8 px strip at the far right of the taskbar with a faint divider.
// A click runs KWin's own "Show Desktop" toggle (the same as Win+D), so there is no state to keep here.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.workspace.dbus as DBus

PlasmoidItem {
    id: root

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.onActivated: toggle()
    toolTipMainText: i18n("Show desktop")

    function toggle() {
        DBus.SessionBus.asyncCall({
            service: "org.kde.kglobalaccel",
            path: "/component/kwin",
            iface: "org.kde.kglobalaccel.Component",
            member: "invokeShortcut",
            arguments: ["Show Desktop"],
            signature: "(s)",
        });
    }

    fullRepresentation: MouseArea {
        id: strip
        Layout.minimumWidth: root.vertical ? -1 : 8
        Layout.maximumWidth: root.vertical ? -1 : 8
        Layout.minimumHeight: root.vertical ? 8 : -1
        Layout.maximumHeight: root.vertical ? 8 : -1
        Layout.fillHeight: !root.vertical
        Layout.fillWidth: root.vertical
        hoverEnabled: true
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: i18n("Show desktop")
        Accessible.onPressAction: root.toggle()
        Keys.onSpacePressed: root.toggle()
        Keys.onReturnPressed: root.toggle()
        onClicked: root.toggle()

        Rectangle { // hover / focus tint over the whole strip
            anchors.fill: parent
            color: Qt.rgba(1, 1, 1, strip.containsMouse || strip.activeFocus ? 0.10 : 0)
        }
        Rectangle { // the divider at the strip's inner edge, like Windows
            x: root.vertical ? (parent.width - width) / 2 : 0
            y: root.vertical ? 0 : (parent.height - height) / 2
            width: root.vertical ? 16 : 1
            height: root.vertical ? 1 : 16
            color: Qt.rgba(1, 1, 1, 0.28)
        }
    }
}
