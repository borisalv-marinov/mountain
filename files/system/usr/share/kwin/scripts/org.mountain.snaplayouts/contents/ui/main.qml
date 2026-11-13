// Win+Z: Windows 11 snap layouts. Runs inside KWin (no extra process); the script's root is the flyout window, hidden until
// the shortcut (like KWin's own examples/quick-script). A popup: KWin's own windows never take keyboard focus, popups get the keys.
import QtQuick
import QtQuick.Window as QQW // org.kde.kwin has its own (uncreatable) Window type
import org.kde.kwin

QQW.Window {
    id: root
    flags: Qt.Popup | Qt.FramelessWindowHint
    color: "transparent"
    width: grid.width + 24
    height: grid.height + 24
    visible: false
    title: "Snap layouts"
    Component.onCompleted: console.warn("mountain-flyout: snaplayouts ready") // one journal line per start, for diagnosis
    onVisibleChanged: console.warn("mountain-flyout: snaplayouts visible=" + visible + " at " + x + "," + y + " " + width + "x" + height)
    onActiveChanged: if (!active && visible) visible = false
    property var target: null
    property Item first: null // the first zone: keyboard focus when the flyout opens
    // [x, y, width, height] as fractions of the work area; one row per layout, like Windows' flyout
    readonly property var layouts: [
        [[0, 0, .5, 1], [.5, 0, .5, 1]],
        [[0, 0, .67, 1], [.67, 0, .33, 1]],
        [[0, 0, .33, 1], [.33, 0, .34, 1], [.67, 0, .33, 1]],
        [[0, 0, .5, 1], [.5, 0, .5, .5], [.5, .5, .5, .5]],
        [[0, 0, .5, .5], [.5, 0, .5, .5], [0, .5, .5, .5], [.5, .5, .5, .5]],
        [[0, 0, .25, 1], [.25, 0, .5, 1], [.75, 0, .25, 1]]
    ]

    function snap(zone) {
        const w = target;
        Qt.callLater(() => root.visible = false); // not from inside the window's own click handler
        if (!w) return;
        const a = Workspace.clientArea(2 /* MaximizeArea */, w);
        if (w.fullScreen) w.fullScreen = false;
        w.setMaximize(false, false);
        w.frameGeometry = Qt.rect(Math.round(a.x + zone[0] * a.width), Math.round(a.y + zone[1] * a.height),
                                  Math.round(zone[2] * a.width), Math.round(zone[3] * a.height));
        Workspace.activeWindow = w;
    }

    ShortcutHandler {
        name: "MountainSnapLayouts"
        text: "Snap layouts"
        sequence: "Meta+Z"
        onActivated: {
            console.warn("mountain-flyout: snaplayouts shortcut");
            if (root.visible) { root.visible = false; return; }
            const w = Workspace.activeWindow;
            if (!w || !w.normalWindow || !w.resizeable || !w.moveable) return;
            root.target = w;
            const g = w.frameGeometry, a = Workspace.clientArea(2, w);
            // under the maximize button (the second of the three caption buttons at the top right)
            root.x = Math.max(a.x + 8, Math.min(g.x + g.width - root.width - 40, a.x + a.width - root.width - 8));
            root.y = Math.max(a.y + 8, Math.min(g.y + 36, a.y + a.height - root.height - 8));
            root.visible = true;
            root.requestActivate();
            if (root.first) root.first.forceActiveFocus();
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: "#e6202020"
        border.color: "#33ffffff"
        Keys.onEscapePressed: root.visible = false

        Grid {
            id: grid
            anchors.centerIn: parent
            columns: 3
            spacing: 12
            Repeater {
                model: root.layouts
                // one layout thumbnail: its zones side by side, each zone a button
                Item {
                    id: thumb
                    readonly property var zones: modelData
                    readonly property int layoutNo: index + 1
                    width: 96; height: 60
                    Repeater {
                        model: thumb.zones
                        Rectangle {
                            id: zoneRect
                            readonly property var zone: modelData
                            x: Math.round(zone[0] * thumb.width) + 1
                            y: Math.round(zone[1] * thumb.height) + 1
                            width: Math.round(zone[2] * thumb.width) - 2
                            height: Math.round(zone[3] * thumb.height) - 2
                            radius: 4
                            color: hover.containsMouse || activeFocus ? "#4cc2ff" : "#40ffffff"
                            border.color: activeFocus ? "#ffffff" : "#26ffffff"
                            activeFocusOnTab: true
                            Component.onCompleted: if (thumb.layoutNo === 1 && index === 0) root.first = zoneRect
                            Accessible.role: Accessible.Button
                            Accessible.name: "Layout " + thumb.layoutNo + ", zone " + (index + 1) + " of " + thumb.zones.length
                            Accessible.onPressAction: root.snap(zone)
                            Keys.onReturnPressed: root.snap(zone)
                            Keys.onEnterPressed: root.snap(zone)
                            Keys.onSpacePressed: root.snap(zone)
                            Keys.onRightPressed: nextItemInFocusChain(true).forceActiveFocus()
                            Keys.onLeftPressed: nextItemInFocusChain(false).forceActiveFocus()
                            MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; onClicked: root.snap(parent.zone) }
                        }
                    }
                }
            }
        }
    }
}
