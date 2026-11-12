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
        radius: 8
        // on = accent, off = white 7 %, hover adds 8 %
        color: button.on ? (button.hovered ? "#76BEFF" : "#5AB0FF")
                         : Qt.rgba(1, 1, 1, button.hovered ? 0.15 : 0.07)
        border.width: button.visualFocus ? 2 : 1
        border.color: button.visualFocus ? (button.on ? "#F2F3F5" : "#5AB0FF") : Qt.rgba(1, 1, 1, 0.14)

        // chrome highlight on the top edge, fading to 0 at the corners
        Rectangle {
            anchors { top: parent.top; topMargin: 1; left: parent.left; right: parent.right; leftMargin: parent.radius; rightMargin: parent.radius }
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.38) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    contentItem: Item {
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.small
            height: width
            source: button.iconSource
            isMask: true
            color: button.on ? "#07080A" : "#F2F3F5"
        }
    }
}
