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
            Accessible.description: tile.available ? "" : i18n("Not available")
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

    // Two lines, always reserved so every row lines up: the name, then "Not available" when the hardware is missing.
    PC3.Label {
        id: label
        Layout.fillWidth: true
        Layout.preferredHeight: Math.ceil(2 * metrics.height)
        text: tile.available ? tile.text : tile.text + "\n" + i18n("Not available")
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignTop
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        maximumLineCount: 2
        color: tile.available ? "#FFFFFF" : "#949494" // 5.9:1 on the flyout
        Accessible.ignored: true
        FontMetrics { id: metrics; font: label.font }
    }
}
