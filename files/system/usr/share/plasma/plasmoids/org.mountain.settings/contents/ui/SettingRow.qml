import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// A clickable settings row: icon, title, one-line description, chevron.
QQC2.AbstractButton {
    id: row
    property string iconName: ""
    property string description: ""
    property bool chevron: true
    property bool divider: false
    Layout.fillWidth: true
    implicitHeight: description !== "" ? 64 : 52
    hoverEnabled: true
    activeFocusOnTab: true
    Accessible.name: text
    Accessible.description: description
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()

    background: Rectangle {
        radius: 10
        color: row.pressed ? Qt.rgba(1, 1, 1, 0.05) : (row.hovered ? app.hover : "transparent")
        border.width: row.visualFocus ? 1 : 0
        border.color: app.accent
        Rectangle {
            visible: row.divider
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 1
            color: Qt.rgba(1, 1, 1, 0.07)
        }
    }

    contentItem: RowLayout {
        spacing: 14
        Item { Layout.preferredWidth: 6 }
        Kirigami.Icon {
            visible: row.iconName !== ""
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            source: row.iconName
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            GText { Layout.fillWidth: true; text: row.text }
            GText {
                Layout.fillWidth: true
                visible: row.description !== ""
                text: row.description
                dim: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
        }
        Kirigami.Icon {
            visible: row.chevron
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            source: "go-next"
            color: app.textDim
            isMask: true
        }
        Item { Layout.preferredWidth: 8 }
    }
}
