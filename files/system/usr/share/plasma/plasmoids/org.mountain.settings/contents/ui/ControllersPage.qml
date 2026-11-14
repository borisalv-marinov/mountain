import QtQuick
import QtQuick.Layouts

// Game controllers: the joystick devices the kernel found (/sys/class/input/js*), by name.
ColumnLayout {
    id: pad
    spacing: 10
    property var pads: []
    Component.onCompleted: app.sh("cat /sys/class/input/js*/device/name 2>/dev/null; true", out => { pads = out === "" ? [] : out.split("\n"); })

    PageTitle { title: "Game controllers" }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        CardHeader { title: "Connected controllers"; subtitle: pad.pads.length === 0 ? "None found. Plug one in or pair it in Bluetooth & devices." : "" }
        Repeater {
            model: pad.pads
            delegate: SettingRow {
                required property string modelData
                required property int index
                text: modelData
                iconName: "input-gamepad"
                chevron: false
                divider: index > 0
            }
        }
    }
}
