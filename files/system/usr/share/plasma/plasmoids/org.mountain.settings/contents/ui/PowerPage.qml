import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Power & battery: screen off and sleep times in powerdevilrc (profiles AC and Battery), then the power service re-reads it;
// the power mode goes through power-profiles-daemon (powerprofilesctl, same service as the quick-settings Energy saver tile).
ColumnLayout {
    id: pw
    spacing: 10
    property var secs: ({}) // "AC.off" -> seconds
    property string mode: ""
    readonly property var times: [0, 60, 120, 300, 600, 900, 1800, 3600]
    readonly property var names: [i18n("Never"), i18n("1 minute"), i18n("2 minutes"), i18n("5 minutes"), i18n("10 minutes"), i18n("15 minutes"), i18n("30 minutes"), i18n("1 hour")]
    readonly property var modes: ["power-saver", "balanced", "performance"]
    readonly property var cards: [{ g: "AC", title: i18n("Plugged in"), off: 300, sleep: 900 }, { g: "Battery", title: i18n("On battery"), off: 120, sleep: 600 }]
    readonly property string rc: "kwriteconfig6 --file powerdevilrc --group "

    function load() {
        let cmd = "(powerprofilesctl get 2>/dev/null || echo balanced); "; // always one line, or the numbers below shift up
        cards.forEach(c => { cmd += "kreadconfig6 --file powerdevilrc --group " + c.g + " --group Display --key TurnOffDisplayIdleTimeoutSec --default " + c.off
            + "; kreadconfig6 --file powerdevilrc --group " + c.g + " --group SuspendAndShutdown --key AutoSuspendIdleTimeoutSec --default " + c.sleep + "; "; });
        app.sh(cmd + "# " + Date.now(), out => {
            const l = out.split("\n");
            mode = l[0];
            secs = { "AC.off": +l[1], "AC.sleep": +l[2], "Battery.off": +l[3], "Battery.sleep": +l[4] };
        });
    }
    // seconds = one of our own numbers; the service re-reads powerdevilrc after the write
    function setOff(g, s) {
        app.sh(rc + g + " --group Display --key TurnOffDisplayWhenIdle --type bool " + (s > 0) + " && " + rc + g + " --group Display --key TurnOffDisplayIdleTimeoutSec " + s + "; " + reload(), load);
    }
    function setSleep(g, s) {
        app.sh(rc + g + " --group SuspendAndShutdown --key AutoSuspendAction " + (s > 0 ? 1 : 0) + " && " + rc + g + " --group SuspendAndShutdown --key AutoSuspendIdleTimeoutSec " + s + "; " + reload(), load);
    }
    function reload() { return "qdbus6 org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement org.kde.Solid.PowerManagement.reparseConfiguration # " + Date.now(); }
    Component.onCompleted: load()

    PageTitle { title: i18n("Power & battery") }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        CardHeader { title: i18n("Power mode"); subtitle: i18n("Battery saver, balanced or best performance") }
        ChoiceRow {
            label: i18n("Power mode")
            model: [i18n("Best power efficiency"), i18n("Balanced"), i18n("Best performance")]
            currentIndex: pw.modes.indexOf(pw.mode)
            onPicked: i => app.sh("powerprofilesctl set " + pw.modes[i] + " # " + Date.now(), pw.load)
        }
        Item { Layout.preferredHeight: 6 }
    }

    Repeater {
        model: pw.cards
        delegate: GlassCard {
            id: card
            required property var modelData
            Layout.fillWidth: true
            padding: 6
            CardHeader { title: card.modelData.title; subtitle: i18n("Screen and sleep") }
            ChoiceRow {
                label: i18n("Turn off my screen after")
                model: pw.names
                currentIndex: pw.times.indexOf(pw.secs[card.modelData.g + ".off"])
                onPicked: i => pw.setOff(card.modelData.g, pw.times[i])
            }
            ChoiceRow {
                label: i18n("Put my PC to sleep after")
                model: pw.names
                currentIndex: pw.times.indexOf(pw.secs[card.modelData.g + ".sleep"])
                onPicked: i => pw.setSleep(card.modelData.g, pw.times[i])
            }
            Item { Layout.preferredHeight: 6 }
        }
    }
}
