import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

// Active Protection (opened from its start-menu entry or the Security page): live status, files checked,
// threats, unverified files to review, quarantine, history. Data and actions: /usr/libexec/mountain-protect.
ColumnLayout {
    id: ap
    spacing: 10

    property var s: ({})
    property string running: ""
    property string note: ""
    readonly property string helper: "/usr/libexec/mountain-protect"
    readonly property string statusCmd: helper + " status"

    function v(k, d) { return s[k] !== undefined ? s[k] : (d || ""); }
    function list(k) { return Array.isArray(s[k]) ? s[k] : []; }
    function q(x) { return "'" + String(x).split("'").join("'\\''") + "'"; }
    function refresh() { exec.connectSource(statusCmd); }
    // update a list in place: delegates (and the buttons in them) stay put; only added or removed rows change
    function sync(model, arr) {
        for (let i = model.count - 1; i >= 0; i--) if (arr.indexOf(model.get(i).v) < 0) model.remove(i);
        for (let i = 0; i < arr.length; i++) {
            if (i < model.count && model.get(i).v === arr[i]) continue;
            let j = -1;
            for (let k = i + 1; k < model.count; k++) if (model.get(k).v === arr[i]) { j = k; break; }
            if (j >= 0) model.move(j, i, 1); else model.insert(i, { v: arr[i] });
        }
        while (model.count > arr.length) model.remove(model.count - 1);
    }
    ListModel { id: unverifiedModel }
    ListModel { id: quarantineModel }
    ListModel { id: historyModel }
    function start(what, cmd) {
        running = what;
        note = "";
        exec.connectSource(cmd + " 2>&1 # " + Date.now());
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            const out = data["stdout"] || "";
            if (source === ap.statusCmd) {
                const m = { ap_unverified: [], av_history: [], av_q: [] };
                for (const l of out.split("\n")) {
                    const i = l.indexOf("=");
                    if (i <= 0) continue;
                    const k = l.slice(0, i), val = l.slice(i + 1);
                    if (Array.isArray(m[k])) m[k].push(val); else m[k] = val;
                }
                if (JSON.stringify(m) !== JSON.stringify(ap.s)) ap.s = m; // most polls change nothing: no rebinding at all
                ap.sync(unverifiedModel, m.ap_unverified);
                ap.sync(quarantineModel, m.av_q);
                ap.sync(historyModel, m.av_history.slice().reverse());
                return;
            }
            if (ap.running === "scan") {
                ap.note = out.indexOf("av_result=found") >= 0 ? "Threats found and moved to quarantine."
                        : out.indexOf("av_result=clean") >= 0 ? "Scan finished: no threats found."
                        : "The scan could not finish. Check your internet connection (definitions download first) and try again.";
            }
            ap.running = "";
            ap.refresh();
        }
    }
    // live only while you look at it: this page is shown, the window is open and in front (minimized or behind = no polling)
    Timer {
        id: poll
        interval: 8000
        repeat: true
        triggeredOnStart: true // fresh numbers the moment the window comes back
        running: ap.visible && !!app.hostWindow && app.hostWindow.visible && app.hostWindow.active
        onTriggered: ap.refresh()
    }
    Component.onCompleted: if (!poll.running) refresh()

    GText {
        Layout.topMargin: 6
        text: "Active Protection"
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2
        font.weight: Font.DemiBold
    }
    GText {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        dim: true
        text: "Watches new files in Downloads, Desktop, Documents, your home folder, temporary files and USB drives, on this PC only: nothing is uploaded. "
              + "It uses almost no memory until a file appears, and never watches games."
    }
    GText {
        Layout.fillWidth: true
        visible: ap.note !== "" || ap.running !== ""
        text: ap.running === "scan" ? "Scanning… definitions download first, then the scan runs at low priority." : ap.running !== "" ? "Working…" : ap.note
        wrapMode: Text.WordWrap
        color: app.accent
    }

    SecurityCard {
        Layout.fillWidth: true
        iconName: ap.v("ap") === "on" ? "security-high" : "security-low"
        title: "Real-time protection is " + (ap.v("ap") === "on" ? "on" : "off")
        level: ap.v("ap") === "on" ? (ap.list("ap_unverified").length > 0 ? 1 : 0) : 2
        details: "Files checked today: " + ap.v("ap_checked_today", "0") + " · Threats blocked: " + ap.v("ap_threats", "0")
                 + " · Unverified to review: " + ap.list("ap_unverified").length
                 + "\nDefinitions: " + (ap.v("av_defs") === "none" ? "not downloaded yet: press Update definitions" : ap.v("av_defs"))
                 + ". They update only when you press Update or a scan button."
        buttons: [
            GlassButton { text: ap.v("ap") === "on" ? "Turn off" : "Turn on"; highlighted: ap.v("ap") !== "on"; enabled: ap.running === ""; onClicked: ap.start("fix", ap.helper + (ap.v("ap") === "on" ? " off" : " on")) },
            GlassButton { text: "Scan now"; enabled: ap.running === ""; onClicked: ap.start("scan", "/usr/libexec/mountain-security scan quick") },
            GlassButton { text: "Update definitions"; enabled: ap.running === ""; onClicked: ap.start("fix", "systemctl start mountain-virus-definitions.service") },
            GlassButton { text: "Security"; onClicked: app.page = "privacy" }
        ]
    }

    GText {
        Layout.topMargin: 10
        visible: ap.list("ap_unverified").length > 0
        text: "Unverified files"
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.25
        font.weight: Font.DemiBold
    }
    Repeater {
        model: unverifiedModel // v = path|reason
        delegate: GlassCard {
            required property string v
            readonly property string path: v.slice(0, v.lastIndexOf("|"))
            readonly property string reason: v.slice(v.lastIndexOf("|") + 1)
            Layout.fillWidth: true
            padding: 12
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    GText { Layout.fillWidth: true; text: path.slice(path.lastIndexOf("/") + 1) }
                    GText { Layout.fillWidth: true; text: reason + " · " + path; dim: true; font.pointSize: Kirigami.Theme.smallFont.pointSize }
                }
                GlassButton { text: "Allow"; Accessible.name: "Allow " + path; onClicked: ap.start("fix", ap.helper + " allow " + ap.q(path)) }
                GlassButton { text: "Quarantine"; Accessible.name: "Quarantine " + path; onClicked: ap.start("fix", ap.helper + " quarantine " + ap.q(path)) }
                GlassButton { text: "Delete"; Accessible.name: "Delete " + path; onClicked: ap.start("fix", ap.helper + " delete " + ap.q(path)) }
            }
        }
    }

    GText {
        Layout.topMargin: 10
        visible: ap.list("av_q").length > 0
        text: "Quarantine"
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.25
        font.weight: Font.DemiBold
    }
    Repeater {
        model: quarantineModel
        delegate: GlassCard {
            required property string v
            Layout.fillWidth: true
            padding: 12
            RowLayout {
                Layout.fillWidth: true
                GText { Layout.fillWidth: true; text: v }
                GlassButton { text: "Restore"; Accessible.name: "Restore " + v; onClicked: ap.start("fix", "/usr/libexec/mountain-security quarantine-restore " + ap.q(v)) }
                GlassButton { text: "Delete"; Accessible.name: "Delete " + v; onClicked: ap.start("fix", "/usr/libexec/mountain-security quarantine-delete " + ap.q(v)) }
            }
        }
    }

    GText {
        Layout.topMargin: 10
        visible: ap.list("av_history").length > 0
        text: "History"
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.25
        font.weight: Font.DemiBold
    }
    Repeater {
        model: historyModel
        delegate: GText {
            required property string v
            Layout.fillWidth: true
            text: v
            dim: true
        }
    }
}
