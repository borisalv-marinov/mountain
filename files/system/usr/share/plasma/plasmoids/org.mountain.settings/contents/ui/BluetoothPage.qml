import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.bluezqt as BluezQt

// Bluetooth & devices > Bluetooth: switch, devices (paired first), Add device scans for 30 s. Calls as in bluedevil's KCM.
// A pairing PIN, when a device asks for one, is shown by Plasma's own Bluetooth service.
ColumnLayout {
    id: page
    spacing: 10
    readonly property bool hasAdapter: BluezQt.Manager.adapters.length > 0
    readonly property bool btOn: BluezQt.Manager.bluetoothOperational && !BluezQt.Manager.bluetoothBlocked
    readonly property var adapter: BluezQt.Manager.usableAdapter

    function setEnabled(enable) {
        BluezQt.Manager.bluetoothBlocked = !enable;
        BluezQt.Manager.adapters.forEach(a => { a.powered = enable; });
    }
    function scan() {
        if (adapter && !adapter.discovering) {
            adapter.startDiscovery();
            stopScan.restart();
        }
    }
    Timer { id: stopScan; interval: 30000; onTriggered: if (page.adapter && page.adapter.discovering) page.adapter.stopDiscovery() }
    Component.onDestruction: if (adapter && adapter.discovering) adapter.stopDiscovery()

    PageTitle { title: i18n("Bluetooth") }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 18
            Layout.preferredHeight: 60
            spacing: 14
            Kirigami.Icon { Layout.preferredWidth: 24; Layout.preferredHeight: 24; source: "preferences-system-bluetooth-symbolic"; fallback: "preferences-system-bluetooth"; isMask: true; color: Kirigami.Theme.textColor }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                GText { Layout.fillWidth: true; text: i18n("Bluetooth") }
                GText {
                    Layout.fillWidth: true
                    dim: true
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    text: !page.hasAdapter ? i18n("No Bluetooth adapter") : page.btOn && page.adapter ? i18n("Discoverable as \"%1\"", page.adapter.name) : i18n("Off")
                }
            }
            GText { visible: page.hasAdapter; text: page.btOn ? i18n("On") : i18n("Off") }
            PillSwitch { visible: page.hasAdapter; text: i18n("Bluetooth"); checked: page.btOn; onClicked: page.setEnabled(!page.btOn) }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 12
            GlassButton {
                text: page.adapter && page.adapter.discovering ? i18n("Searching for devices...") : i18n("Add device")
                highlighted: true
                enabled: page.btOn && page.adapter && !page.adapter.discovering
                opacity: enabled ? 1 : 0.6
                onClicked: page.scan()
            }
        }
    }

    BluezQt.DevicesModel { id: devices }

    GlassCard {
        Layout.fillWidth: true
        visible: page.btOn
        padding: 6
        CardHeader { title: i18n("Devices"); subtitle: i18n("Paired devices and devices found nearby") }
        Repeater {
            model: page.btOn ? devices : null
            delegate: RowLayout {
                id: row
                required property var model
                readonly property var dev: model.Device // read through `model`: role names are capitalised
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 18
                Layout.preferredHeight: 56
                spacing: 12
                Kirigami.Icon { Layout.preferredWidth: 24; Layout.preferredHeight: 24; source: (row.model.Icon || "preferences-system-bluetooth") + "-symbolic"; fallback: row.model.Icon || "preferences-system-bluetooth"; isMask: true; color: Kirigami.Theme.textColor }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    GText { Layout.fillWidth: true; text: row.model.Name }
                    GText {
                        Layout.fillWidth: true
                        text: row.model.Connected ? i18n("Connected") : row.model.Paired ? i18n("Paired") : i18n("Not paired")
                        color: row.model.Connected ? app.accent : app.textDim
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                }
                GlassButton {
                    text: row.model.Connected ? i18n("Disconnect") : row.model.Paired ? i18n("Connect") : i18n("Pair")
                    onClicked: row.model.Connected ? row.dev.disconnectFromDevice() : row.model.Paired ? row.dev.connectToDevice() : row.dev.pair()
                }
                GlassButton {
                    visible: row.model.Paired
                    text: i18n("Remove")
                    onClicked: page.adapter.removeDevice(row.dev)
                }
            }
        }
    }
}
