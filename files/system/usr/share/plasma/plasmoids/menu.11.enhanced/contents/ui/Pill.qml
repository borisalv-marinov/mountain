/*
    Mountain: the Windows 11 start menu button beside a section title ("All >", "More >", "< Back").
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

QQC2.AbstractButton {
    id: pill
    property bool back: false // chevron before the text
    hoverEnabled: true
    activeFocusOnTab: true
    implicitHeight: Math.max(24, row.implicitHeight + 8)
    implicitWidth: row.implicitWidth + 20
    Accessible.role: Accessible.Button
    Accessible.name: text
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()

    background: Rectangle {
        radius: 4 // button token (audit S3-20)
        color: Qt.rgba(1, 1, 1, pill.pressed ? 0.04 : pill.hovered ? 0.12 : 0.07)
        border.width: pill.activeFocus ? 2 : 1
        border.color: pill.activeFocus ? Kirigami.Theme.highlightColor : Qt.rgba(1, 1, 1, 0.10)
    }
    contentItem: Item {
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 6
            layoutDirection: pill.back ? Qt.RightToLeft : Qt.LeftToRight
            QQC2.Label {
                text: pill.text
                color: Kirigami.Theme.textColor
            }
            Kirigami.Icon {
                source: pill.back ? "go-previous" : "go-next"
                Layout.preferredWidth: 12
                Layout.preferredHeight: 12
            }
        }
    }
}
