import QtQuick
import QtQuick.Layouts

// Black glass card: vertical gloss gradient, 1 px rim, inner shadow, brighter top edge.
Rectangle {
    id: card
    default property alias content: column.data
    property int padding: 0
    implicitHeight: column.implicitHeight + padding * 2
    radius: 12
    border.width: 1
    border.color: app.rim
    gradient: Gradient {
        GradientStop { position: 0; color: app.glassTop }
        GradientStop { position: 1; color: app.glassBottom }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 11
        color: "transparent"
        border.width: 1
        border.color: app.innerShadow
    }

    // chrome highlight, fading to 0 at the corners
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: app.rimTop }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    ColumnLayout {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: card.padding }
        spacing: 0
    }
}
