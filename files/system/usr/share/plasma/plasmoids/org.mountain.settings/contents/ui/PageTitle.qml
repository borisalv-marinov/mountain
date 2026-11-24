import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Windows 11 page title with the category as a link back: "System > Sound".
RowLayout {
    property string title: ""
    readonly property bool sameAsCategory: title === app.navCategory.name // "Accessibility" alone, not "Accessibility > Accessibility"
    Layout.topMargin: 6
    Layout.bottomMargin: 14
    Layout.fillWidth: true
    spacing: 10

    QQC2.AbstractButton {
        id: crumb
        visible: !sameAsCategory
        text: app.navCategory.name
        hoverEnabled: true
        activeFocusOnTab: true
        Accessible.name: i18n("Back to %1", text)
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
        visible: !sameAsCategory
        dim: true
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2
    }
    GText {
        Layout.fillWidth: true
        text: parent.title
        Accessible.role: Accessible.Heading // a plain Text is not reliably in the accessibility tree; screen readers and the VM test read the page title here
        Accessible.name: text
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2
        font.weight: Font.DemiBold
    }
}
