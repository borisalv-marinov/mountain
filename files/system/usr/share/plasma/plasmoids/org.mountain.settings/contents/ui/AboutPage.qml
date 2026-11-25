import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

// About: device name (renaming goes through hostnamectl, which asks for the admin password), processor, memory, graphics, Mountain version.
ColumnLayout {
    id: ab
    spacing: 10
    property var rows: []
    property string host: ""

    // os-release MOUNTAIN_VERSION|MOUNTAIN_BUILD, stamped by files/scripts/branding.sh at image build
    function mtVer(s) { const p = (s || "").split("|"); return !p[0] ? "Mountain" : p[1] ? i18n("Mountain %1 (build %2)", p[0], p[1]) : "Mountain " + p[0]; }

    function load() {
        app.sh("echo \"$(hostname)\"; echo \"$(. /usr/lib/os-release; echo \"$MOUNTAIN_VERSION|$MOUNTAIN_BUILD\")\"; echo \"$(lscpu | sed -n 's/^Model name: *//p' | head -1)\"; echo \"$(free -b | awk '/^Mem:/{print $2}')\"; "
            + "echo \"$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | sed 's/^[^ ]* [^:]*: //' | head -2 | paste -sd ';')\" # " + Date.now(), out => {
            const l = out.split("\n");
            host = l[0];
            rows = [
                { t: i18n("Device name"), v: l[0], i: "computer" },
                { t: i18n("Processor"), v: l[2] || i18n("Unknown"), i: "computer" },
                { t: i18n("Installed RAM"), v: l[3] > 0 ? (l[3] / 1073741824).toFixed(1) + " GB" : i18n("Unknown"), i: "media-flash" },
                { t: i18n("Graphics"), v: l[4] || i18n("Unknown"), i: "monitor" },
                { t: i18n("Mountain version"), v: mtVer(l[1]), i: "help-about" }
            ];
        });
    }
    function rename(name) {
        if (/^[A-Za-z0-9][A-Za-z0-9-]{0,62}$/.test(name)) { // letters, digits, hyphens: safe in the command
            app.sh("hostnamectl set-hostname " + name + " # " + Date.now(), load);
        }
    }
    Component.onCompleted: load()

    PageTitle { title: i18n("About") }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        CardHeader { title: i18n("Rename this PC"); subtitle: i18n("Letters, digits and hyphens. You will be asked for your password.") }
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 10
            QQC2.TextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: ab.host
                Accessible.name: i18n("New PC name")
                onAccepted: ab.rename(text)
            }
            GlassButton { text: i18n("Rename"); highlighted: true; enabled: nameField.text !== ""; onClicked: ab.rename(nameField.text) }
        }
    }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        CardHeader { title: i18n("Device specifications") }
        Repeater {
            model: ab.rows
            delegate: SettingRow {
                required property var modelData
                required property int index
                text: modelData.t
                description: modelData.v
                iconName: modelData.i
                chevron: false
                divider: index > 0
            }
        }
    }
}
