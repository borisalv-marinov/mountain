import QtQuick
import QtQuick.Controls as QQC2

// Calm button: glass gradient, rim, white text.
QQC2.AbstractButton {
    id: btn
    property bool highlighted: false
    hoverEnabled: true
    activeFocusOnTab: true
    implicitWidth: Math.max(110, label.implicitWidth + 32)
    implicitHeight: 32
    Accessible.name: text
    Keys.onReturnPressed: clicked()

    background: Rectangle {
        radius: 8
        border.width: 1
        border.color: btn.activeFocus || btn.highlighted ? app.accent : app.rim
        gradient: Gradient {
            GradientStop { position: 0; color: btn.highlighted ? Qt.rgba(1, 1, 1, 0.16) : (btn.hovered ? "#2A2D33" : "#22252B") }
            GradientStop { position: 1; color: btn.highlighted ? Qt.rgba(1, 1, 1, 0.08) : (btn.pressed ? "#07080A" : "#111317") }
        }
    }
    contentItem: GText {
        id: label
        text: btn.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
