import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

// Colors: Dark or Light (same switch as Home) and the accent colour (plasma-apply-colorscheme --accent-color; Plasma 6.1 or newer).
ColumnLayout {
    id: cl
    spacing: 10
    readonly property var swatches: ["#0078D4", "#5AB0FF", "#00B7C3", "#00B294", "#10893E", "#FF8C00", "#E81123", "#C30052", "#881798", "#744DA9", "#68768A", "#7A7574"]

    PageTitle { title: "Colors" }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        CardHeader { title: "Choose your mode"; subtitle: "Mountain looks best in Dark" }
        RowLayout {
            Layout.margins: 12
            spacing: 10
            GlassButton { text: "Dark"; highlighted: app.colorMode === "Dark"; onClicked: app.setColorMode("Dark") }
            GlassButton { text: "Light"; highlighted: app.colorMode === "Light"; onClicked: app.setColorMode("Light") }
        }
    }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        CardHeader { title: "Accent color"; subtitle: "Buttons, links and selections use this color" }
        Flow {
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 8
            Repeater {
                model: cl.swatches
                delegate: QQC2.AbstractButton {
                    id: sw
                    required property string modelData
                    width: 40
                    height: 40
                    hoverEnabled: true
                    activeFocusOnTab: true
                    Accessible.name: "Accent color " + modelData
                    onClicked: app.run("plasma-apply-colorscheme --accent-color '" + modelData + "'")
                    Keys.onReturnPressed: clicked()
                    background: Rectangle {
                        radius: 4
                        color: sw.modelData
                        border.width: sw.visualFocus || sw.hovered ? 2 : 1
                        border.color: sw.visualFocus || sw.hovered ? "#FFFFFF" : app.rim
                    }
                }
            }
        }
    }
}
