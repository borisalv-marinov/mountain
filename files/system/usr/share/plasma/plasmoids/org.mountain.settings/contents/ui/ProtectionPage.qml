import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
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
                ap.note = out.indexOf("av_result=found") >= 0 ? i18n("Threats found and moved to quarantine.")
                        : out.indexOf("av_result=clean") >= 0 ? i18n("Scan finished: no threats found.")
                        : i18n("The scan could not finish. Check your internet connection (definitions download first) and try again.");
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
        text: i18n("Active Protection")
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2
        font.weight: Font.DemiBold
    }
    GText {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        dim: true
        text: i18n("Watches new files in Downloads, Desktop, Documents, your home folder, temporary files and USB drives, on this PC only: nothing is uploaded. ")
              + i18n("When you extract an archive (Ark, Extract here), everything that came out is checked and you get one result. ")
              + i18n("It uses almost no memory until a file appears, and never watches games.")
    }
    GText {
        Layout.fillWidth: true
        visible: ap.note !== "" || ap.running !== ""
        text: ap.running === "scan" ? i18n("Scanning… definitions download first, then the scan runs at low priority.") : ap.running !== "" ? i18n("Working…") : ap.note
        wrapMode: Text.WordWrap
        color: app.accent
    }

    SecurityCard {
        Layout.fillWidth: true
        iconName: ap.v("ap") === "on" ? "security-high" : "security-low"
        title: ap.v("ap") === "on" ? i18n("Real-time protection is on") : i18n("Real-time protection is off")
        level: ap.v("ap") === "on" ? (ap.v("av_defs") === "none" ? 2 : (ap.list("ap_unverified").length > 0 ? 1 : 0)) : 2
        details: i18n("Files checked today: %1 · Threats blocked: %2 · Unverified to review: %3", ap.v("ap_checked_today", "0"), ap.v("ap_threats", "0"), ap.list("ap_unverified").length)
                 + "\n" + i18n("Definitions: %1", ap.v("av_defs") === "none" ? i18n("No virus definitions — press Update") : ap.v("av_defs"))
                 + i18n(". They update only when you press Update or a scan button.")
        buttons: [
            GlassButton { text: ap.v("ap") === "on" ? i18n("Turn off") : i18n("Turn on"); highlighted: ap.v("ap") !== "on"; enabled: ap.running === ""; onClicked: ap.start("fix", ap.helper + (ap.v("ap") === "on" ? " off" : " on")) },
            GlassButton { text: i18n("Scan now"); enabled: ap.running === ""; onClicked: ap.start("scan", "/usr/libexec/mountain-security scan quick") },
            GlassButton { text: i18n("Update definitions"); enabled: ap.running === ""; onClicked: ap.start("fix", "systemctl start mountain-virus-definitions.service") },
            GlassButton { text: i18n("Security"); onClicked: app.page = "privacy" }
        ]
    }

    GText {
        Layout.topMargin: 10
        visible: ap.list("ap_unverified").length > 0
        text: i18n("Unverified files")
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.25
        font.weight: Font.DemiBold
    }
    Repeater {
        model: unverifiedModel // v = path|reason<TAB>plain name<TAB>what it does (mountain-protect plain)
        delegate: GlassCard {
            required property string v
            readonly property var f: v.split("\t")
            readonly property string path: f[0].slice(0, f[0].lastIndexOf("|"))
            readonly property string reason: f[0].slice(f[0].lastIndexOf("|") + 1)
            Layout.fillWidth: true
            padding: 12
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout { // plain name and what it does; the full path on hover and for screen readers
                    Layout.fillWidth: true
                    spacing: 1
                    HoverHandler { id: hv }
                    QQC2.ToolTip.visible: hv.hovered
                    QQC2.ToolTip.text: path
                    Accessible.description: path
                    GText { Layout.fillWidth: true; text: f[1] || path.slice(path.lastIndexOf("/") + 1) }
                    GText { Layout.fillWidth: true; text: f[2] || reason; dim: true; font.pointSize: Kirigami.Theme.smallFont.pointSize }
                }
                GlassButton { text: i18n("Allow"); Accessible.name: i18n("Allow %1", path); onClicked: ap.start("fix", ap.helper + " allow " + ap.q(path)) }
                GlassButton { text: i18n("Quarantine"); Accessible.name: i18n("Quarantine %1", path); onClicked: ap.start("fix", ap.helper + " quarantine " + ap.q(path)) }
                GlassButton { text: i18n("Delete"); Accessible.name: i18n("Delete %1", path); onClicked: ap.start("fix", ap.helper + " delete " + ap.q(path)) }
            }
        }
    }

    GText {
        Layout.topMargin: 10
        visible: ap.list("av_q").length > 0
        text: i18n("Quarantine")
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
                GlassButton { text: i18n("Restore"); Accessible.name: i18n("Restore %1", v); onClicked: ap.start("fix", "/usr/libexec/mountain-security quarantine-restore " + ap.q(v)) }
                GlassButton { text: i18n("Delete"); Accessible.name: i18n("Delete %1", v); onClicked: ap.start("fix", "/usr/libexec/mountain-security quarantine-delete " + ap.q(v)) }
            }
        }
    }

    GText {
        Layout.topMargin: 10
        visible: ap.list("av_history").length > 0
        text: i18n("History")
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
