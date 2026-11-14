import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    property alias cfg_mode: mode.editText
    ComboBox {
        id: mode
        Kirigami.FormData.label: "Shows:"
        editable: true
        model: ["processes", "startup", "users", "services", "device"]
    }
}
