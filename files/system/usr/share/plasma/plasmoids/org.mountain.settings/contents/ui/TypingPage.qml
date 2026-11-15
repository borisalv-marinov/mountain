import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Typing: the two layouts Mountain ships (/etc/xdg/kxkbrc) and how to switch.
ColumnLayout {
    spacing: 10

    PageTitle { title: "Typing" }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        CardHeader { title: "Keyboard layouts"; subtitle: "Switch with Alt+Shift or Win+Space. The tray shows ENG or БГ." }
        SettingRow { text: "English (US)"; description: "ENG"; iconName: "input-keyboard"; chevron: false }
        SettingRow { text: "Bulgarian (Phonetic)"; description: "БГ"; iconName: "input-keyboard"; chevron: false; divider: true }
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 12
            GlassButton {
                text: "Switch layout now"
                onClicked: app.run("qdbus6 org.kde.keyboard /Layouts org.kde.KeyboardLayouts.switchToNextLayout")
            }
        }
    }
}
