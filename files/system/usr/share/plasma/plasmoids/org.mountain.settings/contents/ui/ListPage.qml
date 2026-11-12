import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// A category page or the search results: one glass card per sub-page.
ColumnLayout {
    readonly property bool searching: app.query !== ""
    readonly property var items: searching ? app.searchResults : app.currentCategory.items
    spacing: 6

    GText {
        Layout.topMargin: 6
        Layout.bottomMargin: 14
        Layout.fillWidth: true
        text: searching ? "Results for \"" + app.query.trim() + "\"" : app.currentCategory.name
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2
        font.weight: Font.DemiBold
    }

    GText {
        visible: searching && items.length === 0
        text: "No settings found. Try another word, or open All settings in Updates."
        dim: true
    }

    Repeater {
        model: items
        delegate: GlassCard {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            SettingRow {
                text: modelData.t
                description: modelData.d
                iconName: modelData.i
                onClicked: app.openItem(modelData)
            }
        }
    }

    GText {
        visible: searching && items.length > 0
        Layout.topMargin: 6
        text: "Press Enter to open the first result."
        dim: true
        font.pointSize: Kirigami.Theme.smallFont.pointSize
    }
}
