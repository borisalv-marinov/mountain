// One rounded glass button (a whole tile or one half of a split tile). Tokens: docs/superpowers/plans/2026-11-12-mountain-v5-black-glass.md
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

QQC2.AbstractButton {
    id: button

    property string iconSource
    property bool on: false

    hoverEnabled: true
    activeFocusOnTab: true
    padding: 0
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()

    background: Rectangle {
        radius: 6 // tiles 6 px; cards and flyouts 8 px (audit radii tokens)

        // on = accent, off = raised surface, hover = hover tile (wave/theme.md palette)
        color: button.on ? (button.hovered ? "#1A86D9" : "#0078D4")
                         : (button.hovered && button.enabled ? "#2A2A2A" : "#1E1E1E")
        border.width: button.visualFocus ? 2 : 1
        border.color: button.visualFocus ? (button.on ? "#FFFFFF" : "#5AB0FF") : Qt.rgba(1, 1, 1, 0.08)

        // chrome highlight on the top edge, fading to 0 at the corners
        Rectangle {
            anchors { top: parent.top; topMargin: 1; left: parent.left; right: parent.right; leftMargin: parent.radius; rightMargin: parent.radius }
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.14) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    contentItem: Item {
        // Breeze symbolic glyphs are hairlines at any size; four copies nudged 0.6 px apart embolden them to Fluent-like weight
        Repeater {
            model: [[-0.6, 0], [0.6, 0], [0, -0.6], [0, 0.6]]
            Kirigami.Icon {
                x: (parent.width - width) / 2 + modelData[0]
                y: (parent.height - height) / 2 + modelData[1]
                width: 30
                height: width
                source: button.iconSource
                isMask: true
                color: button.enabled ? "#FFFFFF" : "#B4B4B4" // disabled glyph, readable on #1E1E1E
            }
        }
    }
}
