import QtQuick
import QtQuick.Controls as QQC2

// Pill toggle: accent fill with a dark knob when on, rim outline when off.
// Not checkable on purpose: `checked` stays bound to the backend state; the owner acts in onClicked.
QQC2.AbstractButton {
    id: pill
    hoverEnabled: true
    activeFocusOnTab: true
    implicitWidth: 44
    implicitHeight: 22
    Accessible.role: Accessible.CheckBox
    Accessible.name: text
    Accessible.checked: checked

    background: Rectangle {
        radius: height / 2
        color: pill.checked ? app.accent : (pill.hovered ? app.hover : "transparent")
        border.width: 1
        border.color: pill.visualFocus ? "#FFFFFF" : (pill.checked ? app.accent : app.textDim)
    }
    contentItem: Item {
        Rectangle {
            width: 14
            height: 14
            radius: 7
            anchors.verticalCenter: parent.verticalCenter
            x: pill.checked ? parent.width - width - 4 : 4
            color: pill.checked ? app.glassBottom : app.textColor
        }
    }
}
