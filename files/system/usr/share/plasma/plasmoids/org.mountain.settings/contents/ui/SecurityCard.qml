import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// One Windows Security style tile: icon, title, status (dot + words, never colour alone), details, one-click fixes.
GlassCard {
    id: card
    property string iconName: ""
    property string title: ""
    property int level: 0 // 0 good, 1 recommended, 2 needed
    property string details: ""
    property alias buttons: row.data // the one-click fixes: buttons: [ GlassButton {...} ]
    padding: 16
    Accessible.role: Accessible.Grouping
    Accessible.name: title + ": " + status.text

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Kirigami.Icon {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignTop
            source: card.iconName
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            GText {
                Layout.fillWidth: true
                text: card.title
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
                font.weight: Font.DemiBold
            }
            RowLayout {
                spacing: 6
                Rectangle {
                    width: 10; height: 10; radius: 5
                    color: card.level === 0 ? "#3FB950" : (card.level === 1 ? "#E3B341" : "#FF6A60")
                }
                GText {
                    id: status
                    text: card.level === 0 ? "No action needed" : (card.level === 1 ? "Action recommended" : "Action needed")
                    color: card.level === 0 ? "#7EE2A8" : (card.level === 1 ? "#F2CC60" : "#FF9B94") // all >= 7:1 on the card
                }
            }
            GText {
                Layout.fillWidth: true
                text: card.details
                dim: true
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
            Flow {
                id: row
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 8
            }
        }
    }
}
