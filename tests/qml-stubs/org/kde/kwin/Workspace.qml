pragma Singleton
import QtQuick
// stand-in for KWin's Workspace (only what Mountain's scripts use)
QtObject {
    property var activeWindow: ({ normalWindow: true, resizeable: true, moveable: true, fullScreen: false,
                                  frameGeometry: Qt.rect(100, 100, 800, 500), setMaximize: function () {} })
    property var activeScreen: null
    property var currentDesktop: null
    property point cursorPos: Qt.point(640, 400)
    property string clipboard: "" // what the scripts last put on the clipboard (test only)
    function clientArea(option, a, b) { return Qt.rect(0, 0, 1280, 752); }
}
