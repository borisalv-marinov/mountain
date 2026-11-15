import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Windows 11 page title with the category as a link back: "System > Sound".
RowLayout {
    property string title: ""
    Layout.topMargin: 6
    Layout.bottomMargin: 14
    Layout.fillWidth: true
    spacing: 10

    QQC2.AbstractButton {
        id: crumb
        text: app.navCategory.name
        hoverEnabled: true
        activeFocusOnTab: true
        Accessible.name: "Back to " + text
        onClicked: app.page = app.navPage
        Keys.onReturnPressed: clicked()
        contentItem: GText {
            text: crumb.text
            dim: !crumb.hovered
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2
            font.weight: Font.DemiBold
        }
    }
    GText {
        text: "›"
        dim: true
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2
    }
    GText {
        Layout.fillWidth: true
        text: parent.title
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2
        font.weight: Font.DemiBold
    }
}
