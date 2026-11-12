import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

// Privacy & security: Mountain Security (like Windows Security) on top, then the permission pages.
// Data and actions: /usr/libexec/mountain-security.
ColumnLayout {
    id: sec
    spacing: 10

    property var s: ({})
    property string running: "" // scan | rollback | snapshot | fix
    property string note: ""
    readonly property string statusCmd: "/usr/libexec/mountain-security status"
    readonly property string guide: "https://github.com/borisalv-marinov/mountain/blob/main/docs/OWNER-GUIDE.md"

    function refresh() { exec.connectSource(statusCmd); }
    function start(what, cmd) {
        running = what;
        note = "";
        exec.connectSource(cmd + " 2>&1 # " + Date.now()); // waits for the command; unique so it can run again
    }
    function v(k, d) { return s[k] !== undefined ? s[k] : (d || ""); }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            const out = data["stdout"] || "";
            if (source === sec.statusCmd) {
                const m = {};
                for (const l of out.split("\n")) {
                    const i = l.indexOf("=");
                    if (i > 0) m[l.slice(0, i)] = l.slice(i + 1);
                }
                sec.s = m;
                return;
            }
            if (sec.running === "scan") {
                sec.note = out.indexOf("av_result=found") >= 0 ? "Threats found. They were moved to quarantine, where they can't run."
                         : out.indexOf("av_result=clean") >= 0 ? "Scan finished: no threats found."
                         : "The scan could not finish. Check your internet connection (definitions download first) and try again.";
            } else if (sec.running === "rollback") {
                sec.note = data["exit code"] === 0 ? "Done. Restart your PC to go back to the previous version." : "Going back was cancelled.";
            }
            sec.running = "";
            sec.refresh();
        }
    }
    Component.onCompleted: refresh()

    GText {
        Layout.topMargin: 6
        Layout.bottomMargin: 6
        text: "Privacy & security"
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2
        font.weight: Font.DemiBold
    }
    GText {
        text: "Mountain Security"
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.25
        font.weight: Font.DemiBold
    }
    GText {
        Layout.fillWidth: true
        visible: sec.note !== "" || sec.running !== ""
        text: sec.running === "scan" ? "Scanning your files… Virus definitions download first, then the scan runs at low priority, so games stay smooth."
            : sec.running !== "" ? "Working…" : sec.note
        wrapMode: Text.WordWrap
        color: app.accent
    }

    GridLayout {
        Layout.fillWidth: true
        columns: width > 760 ? 2 : 1
        columnSpacing: 10
        rowSpacing: 10

        SecurityCard {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            iconName: "security-high"
            title: "Virus & threat protection"
            level: sec.v("av_result") === "clean" ? 0 : (sec.v("av_result") === "found" ? 1 : 1)
            details: (sec.v("av_last", "never") === "never" ? "No scan yet." : "Last scan: " + sec.v("av_last") + (sec.v("av_result") === "found" ? " · " + sec.v("av_found") + " found" : sec.v("av_result") === "clean" ? " · no threats" : ""))
                     + "\nDefinitions: " + (sec.v("av_defs") === "none" ? "not downloaded yet" : sec.v("av_defs"))
                     + " · In quarantine: " + sec.v("av_quarantine", "0")
                     + "\nScans and definition downloads run only when you click Scan now. Nothing runs in the background, and games are never scanned."
            buttons: [
                GlassButton { text: "Scan now"; highlighted: true; enabled: sec.running === ""; onClicked: sec.start("scan", "/usr/libexec/mountain-security scan") },
                GlassButton { text: "Open quarantine"; onClicked: app.run("dolphin \"$HOME/.local/share/mountain/quarantine\"") }
            ]
        }
        SecurityCard {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            iconName: "document-revert"
            title: "Ransomware protection"
            level: sec.v("snapshots") === "off" ? 1 : 0
            details: sec.v("snapshots") === "off"
                     ? "Off: Previous versions need the standard Btrfs layout the installer creates."
                     : "Previous versions: " + sec.v("snapshots", "0") + " read-only snapshots of your files, taken every hour. Newest: " + (sec.v("snapshot_last") || "none yet")
                       + "\nPrograms can't change or delete them. To restore, copy a file back from File Explorer › Previous versions."
            buttons: [
                GlassButton { text: "Open Previous versions"; enabled: sec.v("snapshots") !== "off"; onClicked: app.run("dolphin /var/home/.snapshots") },
                GlassButton { text: "Take a snapshot now"; enabled: sec.v("snapshots") !== "off" && sec.running === ""; onClicked: sec.start("snapshot", "systemctl start mountain-snapshot.service") }
            ]
        }
        SecurityCard {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            iconName: "network-firewall"
            title: "Firewall & network protection"
            level: sec.v("fw") === "on" ? 0 : 2
            details: sec.v("fw") === "on"
                     ? "Firewall is on (zone " + sec.v("fw_zone") + "). Open to the network: " + (sec.v("fw_open") || "nothing") + "."
                     : "Firewall is off. Other devices could reach services on this PC."
            buttons: [
                GlassButton { visible: sec.v("fw") !== "on"; text: "Turn on"; highlighted: true; onClicked: sec.start("fix", "systemctl start firewalld") }
            ]
        }
        SecurityCard {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            iconName: "preferences-security"
            title: "App & browser protection"
            level: sec.v("flatpak_tight") === "5/5" ? 0 : 1
            details: "Apps from the App Store run in a sandbox. Chat, browser and office apps can't see your home folder: you pick files in the Open dialog (sandbox tightened for " + sec.v("flatpak_tight", "?") + " of them). Game launchers keep their own access."
            buttons: [
                GlassButton { text: "App permissions"; onClicked: app.openKcm("kcm_app-permissions") }
            ]
        }
        SecurityCard {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            iconName: "cpu"
            title: "Device security"
            level: sec.v("selinux") !== "Enforcing" ? 2 : ((sec.v("sb") === "off" || sec.v("encrypted") === "no") ? 1 : 0)
            details: "Secure Boot: " + (sec.v("sb") === "on" ? "on" : sec.v("sb") === "off" ? "off" : "not supported")
                     + " · TPM: " + (sec.v("tpm") === "yes" ? "yes" : "no")
                     + " · SELinux: " + sec.v("selinux", "?")
                     + "\nKernel lockdown: " + sec.v("lockdown", "?") + " (off by default so game drivers load) · Disk encryption: " + (sec.v("encrypted") === "yes" ? "on" : "off")
            buttons: [
                GlassButton { visible: sec.v("selinux") !== "Enforcing"; text: "Turn on SELinux"; highlighted: true; onClicked: sec.start("fix", "pkexec setenforce 1") },
                GlassButton { visible: sec.v("sb") === "off" || sec.v("encrypted") === "no"; text: "How to turn these on"; onClicked: Qt.openUrlExternally(sec.guide + "#secure-boot-and-disk-encryption") }
            ]
        }
        SecurityCard {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            iconName: "system-software-update"
            title: "Updates & recovery"
            level: sec.v("rollback") === "yes" ? 0 : 1
            details: "This version: " + sec.v("upd_time", "?") + (sec.v("upd_signed") === "yes" ? " · signed updates" : "")
                     + "\n" + (sec.v("rollback") === "yes" ? "The previous version is kept: you can go back at any time, here or in the boot menu." : "No previous version yet (it appears after your first update).")
            buttons: [
                GlassButton { text: "Check for updates"; onClicked: app.run("kstart --application io.github.rfrench3.bazzite-updater") },
                GlassButton { text: "Go back to the previous version"; enabled: sec.v("rollback") === "yes" && sec.running === ""; onClicked: sec.start("rollback", "/usr/libexec/mountain-security rollback") }
            ]
        }
        SecurityCard {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            iconName: "system-users"
            title: "Account protection"
            level: sec.v("password") === "none" ? 2 : (sec.v("screenlock") === "false" ? 1 : 0)
            details: "Password: " + (sec.v("password") === "set" ? "set" : sec.v("password") === "none" ? "none — anyone can use this PC" : "unknown")
                     + " · Screen lock: " + (sec.v("screenlock") === "false" ? "off" : "on")
                     + "\nAdmin tasks always ask for your password."
            buttons: [
                GlassButton { visible: sec.v("password") === "none"; text: "Set a password"; highlighted: true; onClicked: app.openKcm("kcm_users") },
                GlassButton { visible: sec.v("screenlock") === "false"; text: "Turn on screen lock"; onClicked: sec.start("fix", "kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock true") }
            ]
        }
    }

    GText {
        Layout.topMargin: 14
        text: "Permissions"
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.25
        font.weight: Font.DemiBold
    }
    Repeater {
        model: app.currentCategory.items
        delegate: GlassCard {
            required property var modelData
            Layout.fillWidth: true
            SettingRow {
                text: modelData.t
                description: modelData.d
                iconName: modelData.i
                onClicked: app.openItem(modelData)
            }
        }
    }
}
