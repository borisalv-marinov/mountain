/*
    Quick Link menu (Win+X), like Windows 11: above Start, Windows' order, underlined access keys.
    Run with `plasmawindowed org.mountain.winx`; KWin (mountain-altf4 script) removes the frame and places it.
    Windows items with no counterpart here (Mobility Center, Event Viewer, Device Manager, Computer Management) are left out.
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.sessions

PlasmoidItem {
    id: app
    readonly property int menuWidth: 264
    readonly property int subWidth: 220
    readonly property int rowHeight: 30
    property bool sub: false
    property int cur: -1
    property int subCur: 0
    property bool wasActive: false
    property string disk: ""          // partitionmanager or gnome-disks when one is installed
    property bool windowsBoot: false  // Restart into Windows only with a Windows boot entry
    property string pending: ""

    readonly property string diskCmd: "command -v partitionmanager || command -v gnome-disks"
    readonly property string bootCmd: "/usr/libexec/mountain-windows-boot check"
    // plasmawindowed exits when its last window closes: start another plasmawindowed app a moment later, from outside
    function later(c) { return "setsid -f sh -c " + quote("sleep 0.5; exec " + c); }
    function quote(s) { return "'" + s.replace(/'/g, "'\\''") + "'"; }

    readonly property var items: [
        { t: "Installed apps", k: "p", cmd: later("/usr/libexec/mountain-settings-open apps") },
        { t: "Power Options", k: "o", cmd: later("/usr/libexec/mountain-settings-open system") },
        { t: "System", k: "y", cmd: "kinfocenter" },
        { t: "Network Connections", k: "w", cmd: later("/usr/libexec/mountain-settings-open network") },
        { t: "Disk Management", k: "k", cmd: disk, hidden: disk === "" },
        { t: "Terminal", k: "i", cmd: "konsole" },
        { t: "Terminal (Admin)", k: "a", cmd: "konsole -e sudo -i" },
        { sep: true },
        { t: "Task Manager", k: "t", cmd: "plasma-systemmonitor" },
        { t: "Settings", k: "n", cmd: later("plasmawindowed org.mountain.settings") },
        { t: "File Explorer", k: "e", cmd: "dolphin" },
        { t: "Search", k: "s", cmd: "dbus-send --session --type=method_call --dest=org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.activateLauncherMenu" },
        { t: "Run", k: "r", cmd: later("plasmawindowed org.mountain.run") },
        { sep: true },
        { t: "Shut down or sign out", k: "u", submenu: true },
        { t: "Desktop", k: "d", cmd: "dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.showDesktop boolean:true" }
    ].filter(i => !i.hidden)
    readonly property var subItems: [
        { t: "Sign out", k: "i", act: () => session.requestLogout(0) },   // 0 = SessionManagement.Skip: no second question, like Windows
        { t: "Sleep", k: "s", act: () => session.suspend(), hidden: !session.canSuspend },
        { t: "Shut down", k: "u", act: () => session.requestShutdown(0) },
        { t: "Restart", k: "r", act: () => session.requestReboot(0) },
        { t: "Restart into Windows", k: "w", cmd: "/usr/libexec/mountain-windows-boot go", hidden: !windowsBoot }
    ].filter(i => !i.hidden)

    SessionManagement { id: session }

    readonly property var hostWindow: Window.window
    onHostWindowChanged: if (hostWindow) { hostWindow.title = "Quick Link menu"; hostWindow.color = "transparent"; hostWindow.width = menuWidth; hostWindow.height = menuHeight; }
    readonly property int menuHeight: 12 + items.reduce((h, i) => h + (i.sep ? 9 : rowHeight), 0)
    onSubChanged: if (hostWindow) hostWindow.width = sub ? menuWidth + 4 + subWidth : menuWidth
    onMenuHeightChanged: if (hostWindow) hostWindow.height = menuHeight
    Connections {
        target: app.hostWindow
        function onActiveChanged() { // a menu: clicking anywhere else closes it
            if (app.hostWindow.active) app.wasActive = true; else if (app.wasActive) app.close();
        }
        function onVisibleChanged() { if (app.hostWindow.visible) { app.sub = false; app.cur = -1; app.wasActive = false; } }
    }
    preferredRepresentation: fullRepresentation

    function close() { if (hostWindow) hostWindow.close(); }
    function activate(i) {
        if (i.submenu) { sub = true; subCur = 0; return; }
        if (i.act) { i.act(); closeSoon.start(); return; }
        pending = "setsid -f " + i.cmd + " >/dev/null 2>&1";
        if (i.cmd.indexOf("setsid -f") === 0) pending = i.cmd;
        exec.connectSource(pending);
    }
    // close once the request is out: plasmawindowed quits with its last window and would take a half-sent request with it
    Timer { id: closeSoon; interval: 250; onTriggered: app.close() }
    function step(list, at, d) { // next item that isn't a separator
        let n = at;
        for (let c = 0; c < list.length; c++) { n = (n + d + list.length) % list.length; if (!list[n].sep) return n; }
        return at;
    }
    function key(e) {
        const list = sub ? subItems : items;
        const at = sub ? subCur : cur;
        let n = -1;
        if (e.key === Qt.Key_Down) n = step(list, at < 0 ? -1 : at, 1);
        else if (e.key === Qt.Key_Up) n = step(list, at < 0 ? 0 : at, -1);
        else if (e.key === Qt.Key_Home) n = step(list, -1, 1);
        else if (e.key === Qt.Key_End) n = step(list, 0, -1);
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) { if (at >= 0) activate(list[at]); }
        else if (e.key === Qt.Key_Right) { if (!sub && at >= 0 && list[at].submenu) activate(list[at]); }
        else if (e.key === Qt.Key_Left || e.key === Qt.Key_Escape) { if (sub) sub = false; else close(); }
        else {
            const hit = list.find(i => i.k && i.k === e.text.toLowerCase());
            if (hit) { if (sub) subCur = list.indexOf(hit); else cur = list.indexOf(hit); activate(hit); }
            else { e.accepted = false; return; }
        }
        if (n >= 0) { if (sub) subCur = n; else cur = n; }
        e.accepted = true;
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source, data) => {
            if (source === app.diskCmd) app.disk = data.stdout.trim().split("\n")[0];
            else if (source === app.bootCmd) app.windowsBoot = data["exit code"] === 0;
            else if (source === app.pending) { app.pending = ""; app.close(); } // the app runs on by itself (setsid)
            disconnectSource(source);
        }
    }
    Component.onCompleted: { exec.connectSource(diskCmd); exec.connectSource(bootCmd); }

    component Glass: Rectangle {
        radius: 8
        color: Qt.rgba(0.086, 0.09, 0.11, 0.97)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 8; rightMargin: 8; topMargin: 1 }
            height: 1
            color: Qt.rgba(1, 1, 1, 0.14)
        }
    }

    component MenuRow: Item { // no outer ids in here: inline components get their own scope
        id: row
        property var entry: ({}) // not "required": that would hide the Repeater's modelData/index from the delegate bindings
        property bool current: false
        signal picked()
        signal hoveredRow()
        width: parent ? parent.width : 0
        height: entry.sep ? 9 : 30
        Accessible.role: entry.sep ? Accessible.Separator : Accessible.MenuItem
        Accessible.name: entry.t || ""
        Accessible.focused: current
        function label(t, k) { // underline the access key, like Windows
            const at = t.toLowerCase().indexOf(k);
            return at < 0 ? t : t.slice(0, at) + "<u>" + t[at] + "</u>" + t.slice(at + 1);
        }
        Rectangle { visible: row.entry.sep === true; anchors.centerIn: parent; width: parent.width - 16; height: 1; color: Qt.rgba(1, 1, 1, 0.10) }
        Rectangle {
            visible: !row.entry.sep
            anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
            radius: 4
            color: row.current ? Qt.rgba(1, 1, 1, 0.09) : "transparent"
            Rectangle { // Windows 11 focus pill on the left of the current item
                visible: row.current
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                width: 3; height: 16; radius: 1.5
                color: "#5AB0FF"
            }
            Text {
                anchors { left: parent.left; leftMargin: 14; right: chevron.left; verticalCenter: parent.verticalCenter }
                text: row.entry.sep ? "" : row.label(row.entry.t, row.entry.k)
                textFormat: Text.StyledText
                color: "#F2F3F5"
                font: Kirigami.Theme.defaultFont
                elide: Text.ElideRight
            }
            Text {
                id: chevron
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                text: row.entry.submenu ? "›" : ""
                color: "#A4A9B2"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: row.hoveredRow()
                onClicked: row.picked()
            }
        }
    }

    fullRepresentation: Item {
        id: shell
        Layout.minimumWidth: app.menuWidth
        Layout.minimumHeight: app.menuHeight
        Layout.preferredWidth: app.sub ? app.menuWidth + 4 + app.subWidth : app.menuWidth
        Layout.preferredHeight: app.menuHeight
        focus: true
        Keys.onPressed: e => app.key(e)
        Component.onCompleted: forceActiveFocus()

        Glass {
            id: menu
            width: app.menuWidth
            height: parent.height
            Accessible.role: Accessible.PopupMenu
            Accessible.name: "Quick Link menu"
            Column {
                id: list
                anchors { fill: parent; topMargin: 6; bottomMargin: 6 }
                Repeater {
                    model: app.items
                    delegate: MenuRow {
                        entry: modelData
                        current: !app.sub && app.cur === index || app.sub && modelData.submenu === true
                        onPicked: { app.cur = index; app.activate(modelData); }
                        onHoveredRow: if (!modelData.sep) { app.cur = index; if (modelData.submenu) app.activate(modelData); else app.sub = false; }
                    }
                }
            }
        }

        Glass { // "Shut down or sign out" opens to the right, bottom-aligned with its row
            visible: app.sub
            x: app.menuWidth + 4
            width: app.subWidth
            height: 12 + app.subItems.length * app.rowHeight
            y: Math.min(parent.height - height, app.items.slice(0, app.items.findIndex(i => i.submenu)).reduce((h, i) => h + (i.sep ? 9 : app.rowHeight), 0))
            Accessible.role: Accessible.PopupMenu
            Accessible.name: "Shut down or sign out"
            Column {
                anchors { fill: parent; topMargin: 6; bottomMargin: 6 }
                Repeater {
                    model: app.subItems
                    delegate: MenuRow {
                        entry: modelData
                        current: app.sub && app.subCur === index
                        onPicked: { app.subCur = index; app.activate(modelData); }
                        onHoveredRow: app.subCur = index
                    }
                }
            }
        }
    }
}
