import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

// A settings row with a label and a drop-down.
RowLayout {
    property string label
    property bool locked: false
    property alias model: box.model
    property alias currentIndex: box.currentIndex
    signal picked(int index)
    Layout.fillWidth: true
    Layout.leftMargin: 20
    Layout.rightMargin: 18
    Layout.preferredHeight: 48
    enabled: !locked
    GText { Layout.fillWidth: true; text: parent.label }
    QQC2.ComboBox {
        id: box
        Layout.preferredWidth: 220
        Accessible.name: parent.label
        onActivated: i => parent.picked(i)
    }
}
