import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Night light: kwinrc [NightColor] Active, Mode, NightTemperature (same keys as the quick-settings tile); --notify reaches KWin.
ColumnLayout {
    id: nl
    spacing: 10
    property bool on: false
    property bool allDay: false
    property int temp: 4500
    readonly property string base: "kwriteconfig6 --file kwinrc --group NightColor --notify --key "
    readonly property string readCmd: "for k in Active:false Mode:Automatic NightTemperature:4500; do kreadconfig6 --file kwinrc --group NightColor --key ${k%%:*} --default ${k#*:}; done"

    function save(key, value, type) { // value is one of our own literals, never user text
        app.sh(base + key + (type ? " --type " + type : "") + " " + value + " && dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure # " + Date.now(), load);
    }
    function load() {
        app.sh(readCmd + " # " + Date.now(), out => {
            const l = out.split("\n");
            on = l[0] === "true";
            allDay = l[1] === "Constant";
            temp = Math.max(1000, Math.min(6500, parseInt(l[2]) || 4500));
        });
    }
    Component.onCompleted: load()

    PageTitle { title: i18n("Night light") }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 18
            Layout.preferredHeight: 60
            spacing: 14
            Kirigami.Icon { Layout.preferredWidth: 24; Layout.preferredHeight: 24; source: "redshift-status-on-symbolic"; fallback: "redshift-status-on"; isMask: true; color: Kirigami.Theme.textColor }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                GText { Layout.fillWidth: true; text: i18n("Night light") }
                GText { Layout.fillWidth: true; dim: true; text: i18n("Use warmer colors to help you sleep"); font.pointSize: Kirigami.Theme.smallFont.pointSize }
            }
            GText { text: nl.on ? i18n("On") : i18n("Off") }
            PillSwitch { text: i18n("Night light"); checked: nl.on; onClicked: nl.save("Active", nl.on ? "false" : "true", "bool") }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 18
            Layout.bottomMargin: 10
            spacing: 14
            GText { text: i18n("Warmth") }
            QQC2.Slider {
                id: warmth
                Layout.fillWidth: true
                from: 500
                to: 4500
                stepSize: 100
                Accessible.name: i18n("Night light warmth")
                Binding on value { when: !warmth.pressed; value: 6500 - nl.temp }
                onPressedChanged: if (!pressed) nl.save("NightTemperature", String(6500 - Math.round(value)))
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 18
            Layout.bottomMargin: 12
            spacing: 8
            GText { text: i18n("Schedule") }
            Item { Layout.fillWidth: true }
            GlassButton { text: i18n("Sunset to sunrise"); highlighted: !nl.allDay; onClicked: nl.save("Mode", "Automatic") }
            GlassButton { text: i18n("All day"); highlighted: nl.allDay; onClicked: nl.save("Mode", "Constant") }
        }
    }
}
