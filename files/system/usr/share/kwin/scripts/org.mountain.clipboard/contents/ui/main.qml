// Win+V: Windows 11 clipboard history, backed by Klipper's D-Bus (no extra process). The window exists only while shown.
import QtQuick
import QtQuick.Window as QQW // org.kde.kwin has its own (uncreatable) Window type
import org.kde.kwin

Item {
    id: root
    property var items: []
    property string status: ""
    property var previous: null

    function close() {
        Qt.callLater(() => flyout.active = false); // not from inside the window's own click handler
        if (previous) Workspace.activeWindow = previous;
    }
    function call(method, args) {
        dbus.method = method;
        dbus.arguments = args || [];
        dbus.call();
    }
    function clearAll() {
        call("clearClipboardHistory");
        items = [];
    }
    function copy(i) {
        call("setClipboardContents", [items[i]]);
        close(); // Ctrl+V pastes it, as the clipboard now holds this item
    }
    // shortcut: Klipper's D-Bus has no per-item delete, so the history is rebuilt from text (images in it are lost); upgrade when Klipper gets removeItem
    function remove(i) {
        const keep = items.filter((_, n) => n !== i);
        call("clearClipboardHistory");
        for (let n = keep.length - 1; n >= 0; n--) call("setClipboardContents", [keep[n]]);
        items = keep;
    }

    DBusCall {
        id: dbus
        service: "org.kde.klipper"
        path: "/klipper"
        dbusInterface: "org.kde.klipper.klipper"
    }
    DBusCall {
        id: history
        service: "org.kde.klipper"
        path: "/klipper"
        dbusInterface: "org.kde.klipper.klipper"
        method: "getClipboardHistoryMenu"
        onFinished: returnValue => { root.items = returnValue[0] || []; root.status = ""; }
        onFailed: root.status = "Clipboard history isn't available right now."
    }

    ShortcutHandler {
        name: "MountainClipboard"
        text: "Clipboard history"
        sequence: "Meta+V"
        onActivated: {
            if (flyout.active) { root.close(); return; }
            root.previous = Workspace.activeWindow;
            root.items = [];
            history.call();
            flyout.active = true;
        }
    }

    Loader {
        id: flyout
        active: false
        sourceComponent: QQW.Window {
            flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
            color: "transparent"
            width: 360
            height: 450
            visible: true
            title: "Clipboard"
            Component.onCompleted: {
                const a = Workspace.clientArea(2 /* MaximizeArea */, Workspace.activeScreen, Workspace.currentDesktop);
                const p = Workspace.cursorPos;
                x = Math.max(a.x + 8, Math.min(p.x - width / 2, a.x + a.width - width - 8));
                y = Math.max(a.y + 8, Math.min(p.y - 40, a.y + a.height - height - 8));
                requestActivate();
                list.forceActiveFocus();
            }
            onActiveChanged: if (!active) flyout.active = false

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: "#e6202020"
                border.color: "#33ffffff"
                Keys.onEscapePressed: root.close()

                Text {
                    id: heading
                    x: 16; y: 14
                    text: "Clipboard"
                    color: "#ffffff"
                    font.pixelSize: 15; font.bold: true
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }
                Rectangle {
                    id: clearAll
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: heading.verticalCenter }
                    width: clearLabel.width + 20; height: 28; radius: 4
                    visible: root.items.length > 0
                    onVisibleChanged: if (!visible) list.forceActiveFocus() // keep Esc working
                    color: clearMouse.containsMouse || activeFocus ? "#33ffffff" : "transparent"
                    border.color: activeFocus ? "#ffffff" : "transparent"
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: "Clear all"
                    Accessible.onPressAction: root.clearAll()
                    Keys.onReturnPressed: root.clearAll()
                    Keys.onSpacePressed: root.clearAll()
                    Text { id: clearLabel; anchors.centerIn: parent; text: "Clear all"; color: "#4cc2ff"; font.pixelSize: 13 }
                    MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.clearAll() }
                }

                Text {
                    anchors { left: parent.left; right: parent.right; top: heading.bottom; margins: 16 }
                    visible: root.items.length === 0
                    wrapMode: Text.Wrap
                    color: "#c8ffffff"
                    font.pixelSize: 13
                    text: root.status || "Nothing here\n\nYou can paste multiple items from your clipboard history. Copy something, then press Windows key + V."
                }

                ListView {
                    id: list
                    anchors { left: parent.left; right: parent.right; top: heading.bottom; bottom: parent.bottom; margins: 12; topMargin: 16 }
                    clip: true
                    spacing: 8
                    model: root.items
                    keyNavigationEnabled: true
                    activeFocusOnTab: true
                    Accessible.role: Accessible.List
                    Accessible.name: "Clipboard history"
                    Keys.onReturnPressed: if (currentIndex >= 0) root.copy(currentIndex)
                    Keys.onEnterPressed: if (currentIndex >= 0) root.copy(currentIndex)
                    Keys.onDeletePressed: if (currentIndex >= 0) root.remove(currentIndex)

                    delegate: Rectangle {
                        id: card
                        property bool menuOpen: false
                        width: ListView.view.width
                        height: Math.min(body.implicitHeight, 60) + (menuOpen ? 56 : 24)
                        radius: 6
                        readonly property bool current: ListView.isCurrentItem && list.activeFocus
                        color: cardMouse.containsMouse || current ? "#2effffff" : "#1affffff"
                        border.color: current ? "#ffffff" : "#14ffffff"
                        Accessible.role: Accessible.ListItem
                        Accessible.name: modelData
                        Accessible.description: "Press Enter to copy, Delete to remove"
                        Accessible.onPressAction: root.copy(index)

                        MouseArea { id: cardMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.copy(index) }
                        Text {
                            id: body
                            anchors { left: parent.left; right: more.left; top: parent.top; margins: 12 }
                            text: modelData
                            color: "#ffffff"
                            font.pixelSize: 13
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                        Rectangle {
                            id: more
                            anchors { right: parent.right; top: parent.top; margins: 6 }
                            width: 28; height: 28; radius: 4
                            color: moreMouse.containsMouse ? "#33ffffff" : "transparent"
                            Accessible.role: Accessible.Button
                            Accessible.name: "See more"
                            Accessible.onPressAction: card.menuOpen = !card.menuOpen
                            Text { anchors.centerIn: parent; text: "…"; color: "#ffffff"; font.pixelSize: 15 }
                            MouseArea { id: moreMouse; anchors.fill: parent; hoverEnabled: true; onClicked: card.menuOpen = !card.menuOpen }
                        }
                        Rectangle {
                            visible: card.menuOpen
                            anchors { right: parent.right; bottom: parent.bottom; margins: 8 }
                            width: 80; height: 28; radius: 4
                            color: delMouse.containsMouse ? "#33ffffff" : "#1affffff"
                            Accessible.role: Accessible.Button
                            Accessible.name: "Delete"
                            Accessible.onPressAction: root.remove(index)
                            Text { anchors.centerIn: parent; text: "Delete"; color: "#ffffff"; font.pixelSize: 13 }
                            MouseArea { id: delMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.remove(index) }
                        }
                    }
                }
            }
        }
    }
}
