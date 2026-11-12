// Windows 11 style quick-settings tile: a rounded button (optionally split with a › part) and a label under it.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3

ColumnLayout {
    id: tile

    property string text
    property string iconName
    property bool checked: false
    property bool checkable: true
    property bool available: true
    property bool split: false

    signal toggled()
    signal arrowClicked()

    spacing: 6
    opacity: available ? 1 : 0.4

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 48
        spacing: 2

        TileButton {
            Layout.fillWidth: true
            Layout.fillHeight: true
            enabled: tile.available
            on: tile.checked && tile.available
            iconSource: tile.iconName
            Accessible.name: tile.text
            Accessible.checkable: tile.checkable
            Accessible.checked: tile.checked
            onClicked: tile.toggled()
        }
        TileButton {
            visible: tile.split
            Layout.preferredWidth: 30
            Layout.fillHeight: true
            enabled: tile.available
            on: tile.checked && tile.available
            iconSource: "go-next-symbolic"
            Accessible.name: i18n("%1 settings", tile.text)
            onClicked: tile.arrowClicked()
        }
    }

    PC3.Label {
        Layout.fillWidth: true
        text: tile.text
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        maximumLineCount: 1
        color: "#F2F3F5"
        Accessible.ignored: true
    }
}
