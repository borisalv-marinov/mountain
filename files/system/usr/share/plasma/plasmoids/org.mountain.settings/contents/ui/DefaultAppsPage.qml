import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Default apps: browser (xdg-settings), email and file manager (xdg-mime writes mimeapps.list), terminal (kdeglobals TerminalService).
// The lists are the installed .desktop launchers that handle that kind of link, folder or terminal.
ColumnLayout {
    id: da
    spacing: 10
    property var rows: [] // { label, names, ids, cur }
    readonly property var roles: [
        { label: "Web browser", match: "MimeType=.*x-scheme-handler/https", get: "xdg-settings get default-web-browser", set: id => "xdg-settings set default-web-browser " + id },
        { label: "Email", match: "MimeType=.*x-scheme-handler/mailto", get: "xdg-mime query default x-scheme-handler/mailto", set: id => "xdg-mime default " + id + " x-scheme-handler/mailto" },
        { label: "File manager", match: "MimeType=.*inode/directory", get: "xdg-mime query default inode/directory", set: id => "xdg-mime default " + id + " inode/directory" },
        { label: "Terminal", match: "Categories=.*TerminalEmulator", get: "kreadconfig6 --file kdeglobals --group General --key TerminalService", set: id => "kwriteconfig6 --file kdeglobals --group General --key TerminalService " + id }
    ]
    function safe(id) { return /^[A-Za-z0-9._-]+\.desktop$/.test(id); }
    function list(r) { // "Name|file.desktop" lines of visible launchers that match
        return "for f in /usr/share/applications/*.desktop /var/lib/flatpak/exports/share/applications/*.desktop ~/.local/share/flatpak/exports/share/applications/*.desktop ~/.local/share/applications/*.desktop; do "
            + "grep -qE '^" + r.match + "' \"$f\" 2>/dev/null && ! grep -qx 'NoDisplay=true' \"$f\" && echo \"$(grep -m1 '^Name=' \"$f\" | cut -d= -f2)|$(basename \"$f\")\"; done | sort -u";
    }
    function load() {
        roles.forEach((r, i) => app.sh(list(r) + "; echo; " + r.get + " # " + i + " " + Date.now(), out => {
            const l = out.split("\n\n"), apps = l[0].split("\n").filter(x => x.indexOf("|") > 0).map(x => x.split("|")), cur = (l[1] || "").trim();
            const next = rows.slice();
            next[i] = { label: r.label, names: apps.map(a => a[0]), ids: apps.map(a => a[1]), cur: apps.findIndex(a => a[1] === cur) };
            rows = next;
        }));
    }
    Component.onCompleted: load()

    PageTitle { title: "Default apps" }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        Repeater {
            model: da.rows
            delegate: ChoiceRow {
                required property var modelData
                required property int index
                label: modelData ? modelData.label : ""
                model: modelData ? modelData.names : []
                currentIndex: modelData ? modelData.cur : -1
                onPicked: i => {
                    const id = modelData.ids[i];
                    if (da.safe(id)) {
                        app.sh(da.roles[index].set(id) + " # " + Date.now(), da.load);
                    }
                }
            }
        }
        Item { Layout.preferredHeight: 6 }
    }
    GText { text: "To choose which app opens one kind of file, right-click the file and pick Open with."; dim: true; wrapMode: Text.WordWrap; Layout.fillWidth: true }
}
