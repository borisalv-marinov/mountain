import QtQuick
import QtQuick.Controls as QQC2

// Calm button: flat fill, rim, white text.
QQC2.AbstractButton {
    id: btn
    property bool highlighted: false
    hoverEnabled: true
    activeFocusOnTab: true
    implicitWidth: Math.max(110, label.implicitWidth + 32)
    implicitHeight: 32
    Accessible.name: text
    Keys.onReturnPressed: clicked()

    // Windows 11: highlighted = the one accent-filled (primary or selected) button, the rest lighter than the card
    background: Rectangle {
        radius: 4
        border.width: btn.visualFocus ? 2 : 1
        border.color: btn.visualFocus ? "#FFFFFF" : btn.highlighted ? app.accent : app.rim
        color: btn.highlighted ? (btn.pressed ? "#4A9AE6" : btn.hovered ? "#6BB9FF" : app.accent)
                               : (btn.pressed ? "#2E3036" : btn.hovered ? "#45474E" : "#3B3D43")
    }
    contentItem: GText {
        id: label
        text: btn.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: btn.highlighted ? "#000000" : btn.enabled ? app.textColor : app.textDim // dim stays >= 4.5:1 on the button
    }
}
