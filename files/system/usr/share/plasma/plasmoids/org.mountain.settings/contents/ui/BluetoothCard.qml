import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.bluezqt as BluezQt

// Home "Bluetooth devices" card. Loaded through a Loader so a missing bluez-qt module only hides it.
GlassCard {
    id: bt
    readonly property bool hasAdapter: BluezQt.Manager.adapters.length > 0
    readonly property bool btOn: BluezQt.Manager.bluetoothOperational && !BluezQt.Manager.bluetoothBlocked
    padding: 6

    // Same as the Plasma Bluetooth applet (bluedevil applet main.qml setBluetoothEnabled).
    function setEnabled(enable) {
        BluezQt.Manager.bluetoothBlocked = !enable;
        BluezQt.Manager.adapters.forEach(adapter => {
            adapter.powered = enable;
        });
    }

    CardHeader { title: "Bluetooth devices"; subtitle: "Manage, add, and remove devices" }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 20
        Layout.rightMargin: 18
        Layout.preferredHeight: 56
        spacing: 14
        Kirigami.Icon {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            source: "preferences-system-bluetooth"
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            GText { Layout.fillWidth: true; text: "Bluetooth" }
            GText {
                Layout.fillWidth: true
                dim: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                text: !bt.hasAdapter ? "No Bluetooth adapter"
                    : (bt.btOn && BluezQt.Manager.usableAdapter ? "Discoverable as \"" + BluezQt.Manager.usableAdapter.name + "\"" : "Off")
            }
        }
        GText {
            visible: bt.hasAdapter
            text: bt.btOn ? "On" : "Off"
        }
        PillSwitch {
            visible: bt.hasAdapter
            text: "Bluetooth"
            checked: bt.btOn
            onClicked: bt.setEnabled(!bt.btOn)
        }
    }

    BluezQt.DevicesModel {
        id: devicesModel
    }

    Repeater {
        model: bt.hasAdapter ? devicesModel : null
        delegate: RowLayout {
            // role names are capitalised (Name, Connected...), so read them through `model`
            id: devRow
            required property var model
            required property int index
            visible: devRow.model.Paired && devRow.index < 6
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 18
            Layout.preferredHeight: 52
            spacing: 14
            Kirigami.Icon {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                source: devRow.model.Icon || "preferences-system-bluetooth"
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                GText { Layout.fillWidth: true; text: devRow.model.Name }
                GText {
                    Layout.fillWidth: true
                    text: devRow.model.Connected ? "Connected" : "Not connected"
                    color: devRow.model.Connected ? app.accent : app.textDim
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 14
        Layout.bottomMargin: 6
        spacing: 8
        SettingRow {
            text: "View all devices"
            chevron: false
            onClicked: app.openKcm("kcm_bluetooth")
        }
        GlassButton {
            text: "Add device"
            enabled: bt.hasAdapter
            opacity: enabled ? 1 : 0.5
            onClicked: app.openKcm("kcm_bluetooth")
        }
    }
}
