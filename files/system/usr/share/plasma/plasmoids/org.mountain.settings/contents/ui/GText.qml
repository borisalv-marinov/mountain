import QtQuick
import org.kde.kirigami as Kirigami

// Plain text in the glass palette with the system font.
Text {
    property bool dim: false
    color: dim ? app.textDim : app.textColor
    font.family: Kirigami.Theme.defaultFont.family
    font.pointSize: Kirigami.Theme.defaultFont.pointSize
    elide: Text.ElideRight
    textFormat: Text.PlainText
}
