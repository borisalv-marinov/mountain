// Mountain Quick settings: Windows 11 style flyout (tiles, sliders, battery, Settings gear) on Plasma's own backends.
// Every backend lives in its own file behind a Loader, so a missing QML module only dims that part.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils

PlasmoidItem {
    id: root

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.icon: "preferences-system-network"
    preferredRepresentation: compactRepresentation
    toolTipMainText: i18n("Quick settings")
    toolTipSubText: i18n("Network, volume, battery")

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => disconnectSource(source)
    }

    // A tile whose backend may be missing: on a load error it shows a dim stand-in.
    component OptionalTile: Item {
        id: optional
        property alias source: loader.source
        property string fallbackText
        property string fallbackIcon
        implicitHeight: loader.status === Loader.Ready ? loader.item.implicitHeight : stand.implicitHeight
        Loader { id: loader; anchors.left: parent.left; anchors.right: parent.right }
        Tile {
            id: stand
            anchors.left: parent.left
            anchors.right: parent.right
            visible: loader.status === Loader.Error
            available: false
            text: optional.fallbackText
            iconName: optional.fallbackIcon
        }
    }

    // In the tray every item is a square cell, so show one icon there; in the panel show the Windows-style group.
    compactRepresentation: MouseArea {
        id: compact
        readonly property bool inTray: (Plasmoid.containmentDisplayHints & PlasmaCore.Types.ContainmentForcesSquarePlasmoids) !== 0
        readonly property int iconSize: inTray ? Math.min(width, height) : Kirigami.Units.iconSizes.small
        property bool wasExpanded: false

        Layout.minimumWidth: root.vertical ? 0 : inTray ? height : icons.implicitWidth + 2 * Kirigami.Units.smallSpacing
        Layout.minimumHeight: !root.vertical ? 0 : inTray ? width : icons.implicitHeight + 2 * Kirigami.Units.smallSpacing
        Layout.preferredWidth: Layout.minimumWidth
        Layout.preferredHeight: Layout.minimumHeight
        hoverEnabled: true
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: i18n("Quick settings")
        Accessible.description: i18n("Network, volume and battery")
        Accessible.onPressAction: root.expanded = !root.expanded
        Keys.onSpacePressed: root.expanded = !root.expanded
        onPressed: wasExpanded = root.expanded
        onClicked: root.expanded = !wasExpanded

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: Qt.rgba(1, 1, 1, compact.containsMouse || root.expanded ? 0.08 : 0)
            border.width: compact.activeFocus ? 1 : 0
            border.color: "#5AB0FF"
        }
        GridLayout {
            id: icons
            anchors.centerIn: parent
            flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rows: root.vertical ? -1 : 1
            columns: root.vertical ? 1 : -1
            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: Kirigami.Units.smallSpacing
            Loader {
                source: "NetIcon.qml"
                Layout.preferredWidth: compact.iconSize
                Layout.preferredHeight: compact.iconSize
            }
            Loader {
                source: "VolIcon.qml"
                active: !compact.inTray
                visible: active
                Layout.preferredWidth: compact.iconSize
                Layout.preferredHeight: compact.iconSize
            }
            Loader {
                id: battery
                source: "BatteryLabel.qml"
                active: !compact.inTray
                visible: active && item !== null && item.present
                onLoaded: { item.showText = false; item.iconSize = Qt.binding(() => compact.iconSize); }
            }
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: 360
        Layout.minimumWidth: 360
        Layout.maximumWidth: 360
        Layout.minimumHeight: implicitHeight
        Layout.preferredHeight: implicitHeight
        spacing: 12

        GridLayout {
            id: grid
            readonly property real tileWidth: (width - 2 * columnSpacing) / 3
            Layout.fillWidth: true
            Layout.margins: 4
            columns: 3
            columnSpacing: 12
            rowSpacing: 14

            OptionalTile { Layout.preferredWidth: grid.tileWidth; source: "WifiTile.qml"; fallbackText: i18n("Wi-Fi unavailable"); fallbackIcon: "network-wireless-disconnected-symbolic" }
            OptionalTile { Layout.preferredWidth: grid.tileWidth; source: "BluetoothTile.qml"; fallbackText: i18n("Bluetooth unavailable"); fallbackIcon: "preferences-system-bluetooth-symbolic" }
            OptionalTile { Layout.preferredWidth: grid.tileWidth; source: "AirplaneTile.qml"; fallbackText: i18n("Airplane mode"); fallbackIcon: "network-flightmode-off" }
            OptionalTile { Layout.preferredWidth: grid.tileWidth; source: "EnergyTile.qml"; fallbackText: i18n("Energy saver unavailable"); fallbackIcon: "battery-profile-powersave-symbolic" }
            Tile {
                Layout.preferredWidth: grid.tileWidth
                text: i18n("Accessibility")
                iconName: "preferences-desktop-accessibility-symbolic"
                checkable: false
                split: true
                onToggled: KCMUtils.KCMLauncher.openSystemSettings("kcm_access")
                onArrowClicked: KCMUtils.KCMLauncher.openSystemSettings("kcm_access")
            }
            OptionalTile { Layout.preferredWidth: grid.tileWidth; source: "NightLightTile.qml"; fallbackText: i18n("Night light unavailable"); fallbackIcon: "redshift-status-off" }
        }

        // Sliders card: glass gradient, 1 px rim, top-edge highlight, 12 px radius
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: sliders.implicitHeight + 24
            radius: 12
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.14)
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#1B1D22" }
                GradientStop { position: 1.0; color: "#07080A" }
            }
            Rectangle {
                anchors { top: parent.top; topMargin: 1; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.38) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            ColumnLayout {
                id: sliders
                anchors { fill: parent; margins: 12 }
                spacing: 8
                Loader {
                    source: "BrightnessRow.qml"
                    Layout.fillWidth: true
                }
                Loader {
                    id: volumeRow
                    source: "VolumeRow.qml"
                    Layout.fillWidth: true
                }
                PC3.Label {
                    visible: volumeRow.status === Loader.Error
                    text: i18n("Sound service unavailable")
                    color: "#A4A9B2"
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            Loader { source: "BatteryLabel.qml" }
            Item { Layout.fillWidth: true }
            PC3.ToolButton {
                icon.name: "configure-symbolic"
                display: PC3.AbstractButton.IconOnly
                text: i18n("Open Settings")
                Accessible.name: text
                PC3.ToolTip.text: text
                PC3.ToolTip.visible: hovered
                onClicked: {
                    root.expanded = false;
                    exec.connectSource("plasmawindowed org.mountain.settings >/dev/null 2>&1 &");
                }
            }
        }
    }
}
