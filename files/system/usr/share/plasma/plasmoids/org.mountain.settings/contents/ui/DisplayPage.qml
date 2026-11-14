import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Display: resolution, refresh rate, scale, HDR and adaptive sync per screen through kscreen-doctor (Plasma's own CLI for
// the same service as KDE's Display page). A change is undone after 15 s unless you keep it, so a bad mode can't strand you.
ColumnLayout {
    id: disp
    spacing: 10
    property var outputs: []
    property string status: "Looking for screens..."
    property string undoCmd: ""
    property int countdown: 0
    readonly property var scales: [1, 1.25, 1.5, 1.75, 2]
    readonly property bool busy: undoCmd !== ""

    function safe(s) { return /^[A-Za-z0-9_.@-]+$/.test(String(s)); }
    function load() {
        app.sh("kscreen-doctor -j # " + Date.now(), out => {
            try {
                outputs = JSON.parse(out).outputs.filter(o => o.enabled && safe(o.name));
                status = outputs.length ? "" : "No screens found.";
            } catch (e) {
                outputs = [];
                status = "Display information is not available.";
            }
        });
    }
    function modeOf(o) { return o.modes.find(m => String(m.id) === String(o.currentModeId)) || o.modes[0]; }
    function sizeKey(m) { return m.size.width + "x" + m.size.height; }
    function sizes(o) { // unique sizes, largest first
        const seen = {}, out = [];
        o.modes.forEach(m => { if (!seen[sizeKey(m)]) { seen[sizeKey(m)] = true; out.push(m); } });
        return out.sort((a, b) => b.size.width * b.size.height - a.size.width * a.size.height);
    }
    function rates(o) { return o.modes.filter(m => sizeKey(m) === sizeKey(modeOf(o))).sort((a, b) => b.refreshRate - a.refreshRate); }
    // run `output.NAME.KEY.VALUE`, offering to undo it with the old value
    function change(o, key, value, old) {
        if (!safe(value) || !safe(old)) {
            return;
        }
        const f = v => "kscreen-doctor output." + o.name + "." + key + "." + v;
        app.sh(f(value), () => { undoCmd = f(old); countdown = 15; confirm.restart(); load(); });
    }
    function setNow(o, key, value) { app.sh("kscreen-doctor output." + o.name + "." + key + "." + value, load); }
    function keep() { confirm.stop(); undoCmd = ""; }
    function revert() {
        confirm.stop();
        app.sh(undoCmd, () => { undoCmd = ""; load(); });
    }
    Timer {
        id: confirm
        interval: 1000
        repeat: true
        onTriggered: { if (--disp.countdown <= 0) disp.revert(); }
    }
    Component.onCompleted: load()

    PageTitle { title: "Display" }

    GlassCard {
        Layout.fillWidth: true
        visible: disp.busy
        padding: 6
        CardHeader { title: "Keep these display settings?"; subtitle: "Going back in " + disp.countdown + " seconds" }
        RowLayout {
            Layout.margins: 12
            spacing: 8
            GlassButton { text: "Keep changes"; highlighted: true; onClicked: disp.keep() }
            GlassButton { text: "Revert"; onClicked: disp.revert() }
        }
    }

    GText { visible: disp.status !== ""; text: disp.status; dim: true }

    Repeater {
        model: disp.outputs
        delegate: GlassCard {
            id: card
            required property var modelData
            required property int index
            readonly property var o: modelData
            readonly property var cur: disp.modeOf(o)
            Layout.fillWidth: true
            padding: 6
            CardHeader { title: "Display " + (card.index + 1); subtitle: card.o.name + " · " + card.cur.size.width + " x " + card.cur.size.height }

            ChoiceRow {
                locked: disp.busy
                label: "Resolution"
                model: disp.sizes(card.o).map(m => m.size.width + " x " + m.size.height)
                currentIndex: disp.sizes(card.o).findIndex(m => disp.sizeKey(m) === disp.sizeKey(card.cur))
                onPicked: i => {
                    const want = disp.sizes(card.o)[i], same = card.o.modes.filter(m => disp.sizeKey(m) === disp.sizeKey(want));
                    const best = same.sort((a, b) => Math.abs(a.refreshRate - card.cur.refreshRate) - Math.abs(b.refreshRate - card.cur.refreshRate))[0];
                    disp.change(card.o, "mode", best.id, card.cur.id);
                }
            }
            ChoiceRow {
                locked: disp.busy
                label: "Refresh rate"
                model: disp.rates(card.o).map(m => m.refreshRate.toFixed(0) + " Hz")
                currentIndex: disp.rates(card.o).findIndex(m => String(m.id) === String(card.cur.id))
                onPicked: i => disp.change(card.o, "mode", disp.rates(card.o)[i].id, card.cur.id)
            }
            ChoiceRow {
                locked: disp.busy
                label: "Scale"
                model: disp.scales.map(s => Math.round(s * 100) + "%")
                currentIndex: disp.scales.findIndex(s => Math.abs(s - card.o.scale) < 0.05)
                onPicked: i => disp.change(card.o, "scale", disp.scales[i], card.o.scale)
            }
            RowLayout {
                visible: card.o.hdr !== undefined
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 18
                Layout.preferredHeight: 48
                GText { Layout.fillWidth: true; text: "HDR" }
                PillSwitch { text: "HDR"; checked: card.o.hdr === true; onClicked: disp.setNow(card.o, "hdr", card.o.hdr ? "disable" : "enable") }
            }
            RowLayout {
                visible: card.o.vrrPolicy !== undefined
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 18
                Layout.preferredHeight: 48
                GText { Layout.fillWidth: true; text: "Variable refresh rate (adaptive sync)" }
                PillSwitch { text: "Variable refresh rate"; checked: card.o.vrrPolicy !== 0; onClicked: disp.setNow(card.o, "vrrpolicy", card.o.vrrPolicy === 0 ? "automatic" : "never") }
            }
            Item { Layout.preferredHeight: 6 }
        }
    }
}
