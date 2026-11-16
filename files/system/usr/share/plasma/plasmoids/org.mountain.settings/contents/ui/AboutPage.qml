import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

// About: device name (renaming goes through hostnamectl, which asks for the admin password), processor, memory, graphics, Mountain version.
ColumnLayout {
    id: ab
    spacing: 10
    property var rows: []
    property string host: ""

    function load() {
        app.sh("echo \"$(hostname)\"; echo \"$(. /etc/os-release; echo $PRETTY_NAME)\"; echo \"$(lscpu | sed -n 's/^Model name: *//p' | head -1)\"; echo \"$(free -b | awk '/^Mem:/{print $2}')\"; "
            + "echo \"$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | sed 's/^[^ ]* [^:]*: //' | head -2 | paste -sd ';')\" # " + Date.now(), out => {
            const l = out.split("\n");
            host = l[0];
            rows = [
                { t: "Device name", v: l[0], i: "computer" },
                { t: "Processor", v: l[2] || "Unknown", i: "computer" },
                { t: "Installed RAM", v: l[3] > 0 ? (l[3] / 1073741824).toFixed(1) + " GB" : "Unknown", i: "media-flash" },
                { t: "Graphics", v: l[4] || "Unknown", i: "monitor" },
                { t: "Mountain version", v: l[1] || "Unknown", i: "help-about" }
            ];
        });
    }
    function rename(name) {
        if (/^[A-Za-z0-9][A-Za-z0-9-]{0,62}$/.test(name)) { // letters, digits, hyphens: safe in the command
            app.sh("hostnamectl set-hostname " + name + " # " + Date.now(), load);
        }
    }
    Component.onCompleted: load()

    PageTitle { title: "About" }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        CardHeader { title: "Rename this PC"; subtitle: "Letters, digits and hyphens. You will be asked for your password." }
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 10
            QQC2.TextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: ab.host
                Accessible.name: "New PC name"
                onAccepted: ab.rename(text)
            }
            GlassButton { text: "Rename"; highlighted: true; enabled: nameField.text !== ""; onClicked: ab.rename(nameField.text) }
        }
    }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        CardHeader { title: "Device specifications" }
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
