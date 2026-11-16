import QtQuick
import QtQuick.Layouts

// Date & time: automatic time and the time zone go through timedatectl (it asks for the admin password);
// the 24-hour clock sets the time format in plasma-localerc (needs a sign-out), like Language & region.
ColumnLayout {
    id: dt
    spacing: 10
    property bool auto: true
    property bool h24: false
    property bool changed: false
    property string zone: ""
    property var zones: []

    function load() {
        app.sh("timedatectl show; echo \"LC_TIME=$(kreadconfig6 --file plasma-localerc --group Formats --key LC_TIME)\" # " + Date.now(), out => {
            const v = k => (out.match(new RegExp("^" + k + "=(.*)$", "m")) || [])[1] || "";
            auto = v("NTP") !== "no";
            zone = v("Timezone");
            h24 = v("LC_TIME") !== "" && v("LC_TIME").indexOf("en_US") !== 0;
        });
    }
    function setZone(z) { // z comes from timedatectl's own list
        if (/^[A-Za-z0-9_+\/-]+$/.test(z)) {
            app.sh("timedatectl set-timezone " + z + " # " + Date.now(), load);
        }
    }
    function flipAuto() { app.sh("timedatectl set-ntp " + (auto ? "false" : "true") + " # " + Date.now(), load); }
    function toggle24() {
        app.sh("kwriteconfig6 --file plasma-localerc --group Formats --key LC_TIME " + (h24 ? "en_US.UTF-8" : "en_GB.UTF-8") + " # " + Date.now(), () => { changed = true; load(); });
    }
    Component.onCompleted: {
        load();
        app.sh("timedatectl list-timezones", out => { zones = out.split("\n").filter(z => z !== ""); });
    }

    PageTitle { title: "Date & time" }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        SettingRow {
            text: "Set time automatically"
            description: "Uses the internet to keep the clock right"
            iconName: "clock"
            chevron: false
            onClicked: dt.flipAuto()
            trailing: PillSwitch { text: "Set time automatically"; checked: dt.auto; onClicked: dt.flipAuto() }
        }
        ChoiceRow {
            label: "Time zone"
            model: dt.zones
            currentIndex: dt.zones.indexOf(dt.zone)
            onPicked: i => dt.setZone(dt.zones[i])
        }
        SettingRow {
            text: "Use the 24-hour clock"
            description: dt.changed ? "Sign out and back in to see it" : "Shows 14:30 instead of 2:30 PM"
            iconName: "clock"
            chevron: false
            divider: true
            onClicked: dt.toggle24()
            trailing: PillSwitch { text: "Use the 24-hour clock"; checked: dt.h24; onClicked: dt.toggle24() }
        }
        GlassButton {
            visible: dt.changed
            Layout.margins: 12
            text: "Sign out now"
            onClicked: app.run("qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logout")
        }
    }
}
