import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Card title with an optional dim subtitle, like the Windows 11 Home cards.
ColumnLayout {
    property string title: ""
    property string subtitle: ""
    Layout.fillWidth: true
    Layout.leftMargin: 18
    Layout.rightMargin: 18
    Layout.topMargin: 14
    Layout.bottomMargin: 10
    spacing: 4
    Accessible.role: Accessible.StaticText
    Accessible.name: title

    GText {
        Layout.fillWidth: true
        text: parent.title
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.25
        font.weight: Font.DemiBold
    }
    GText {
        Layout.fillWidth: true
        visible: parent.subtitle !== ""
        text: parent.subtitle
        dim: true
    }
}
