import QtQuick
QtObject {
    objectName: "shortcut"
    property string name
    property string text
    property var sequence
    signal activated()
}
