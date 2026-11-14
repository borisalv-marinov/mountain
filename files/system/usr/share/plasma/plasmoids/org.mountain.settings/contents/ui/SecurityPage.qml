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
    property var ap: ({}) // mountain-protect status: Active Protection on/off, files checked today, threats
    property string running: "" // scan | rollback | snapshot | fix
    property string note: ""
    readonly property string statusCmd: "/usr/libexec/mountain-security status"
    readonly property string guide: "https://github.com/borisalv-marinov/mountain/blob/main/docs/OWNER-GUIDE.md"

    readonly property string apCmd: "/usr/libexec/mountain-protect status"
    function refresh() { exec.connectSource(statusCmd); exec.connectSource(apCmd); }
    function a(k, d) { return ap[k] !== undefined ? ap[k] : (d || ""); }
    // one level per tile (0 good, 1 recommended, 2 needed); the headline is the worst of them
    readonly property int lvAv: v("av_defs") === "none" ? 2 : (v("av_result") === "found" ? 1 : 0)
    readonly property int lvAp: a("ap") === "on" ? 0 : 2
    readonly property int lvFw: v("fw") === "on" ? 0 : 2
    readonly property int lvApp: v("flatpak_tight") === "5/5" ? 0 : 1
    readonly property int lvDev: v("selinux") !== "Enforcing" ? 2 : ((v("sb") === "off" || v("encrypted") === "no") ? 1 : 0)
    readonly property bool loaded: s.fw !== undefined && ap.ap !== undefined
    readonly property int overall: !loaded ? 0 : Math.max(lvAv, lvAp, lvFw, lvApp, lvDev)
    function start(what, cmd) {
        running = what;
        note = "";
        exec.connectSource(cmd + " 2>&1 # " + Date.now()); // waits for the command; unique so it can run again
    }
    function v(k, d) { return s[k] !== undefined ? s[k] : (d || ""); }
    function list(k) { return Array.isArray(s[k]) ? s[k] : []; }
    readonly property string helper: "/usr/libexec/mountain-security"
    function q(x) { return "'" + String(x).split("'").join("'\\''") + "'"; }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            const out = data["stdout"] || "";
            if (source === sec.statusCmd || source === sec.apCmd) {
                const m = { fw_app: [], av_history: [], av_q: [] };
                for (const l of out.split("\n")) {
                    const i = l.indexOf("=");
                    if (i <= 0) continue;
                    const k = l.slice(0, i), val = l.slice(i + 1);
                    if (Array.isArray(m[k])) m[k].push(val); else m[k] = val;
                }
                if (source === sec.apCmd) sec.ap = m; else sec.s = m;
                return;
            }
            if (sec.running === "scan") {
                sec.note = out.indexOf("av_result=cancelled") >= 0 ? ""
                         : out.indexOf("av_result=found") >= 0 ? "Threats found. They were moved to quarantine, where they can't run."
                         : out.indexOf("av_result=clean") >= 0 ? "Scan finished: no threats found."
                         : out.indexOf("av_result=no-definitions") >= 0 ? "No virus definitions yet. Connect to the internet and press Scan now to download them."
                         : "The scan could not finish. Try again, or see Active Protection's log.";
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
    GlassCard { // Windows Security's home: one sentence that says whether you need to do anything
        Layout.fillWidth: true
        padding: 16
        Accessible.role: Accessible.StaticText
        Accessible.name: headline.text + ". " + sub.text
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Kirigami.Icon {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                source: sec.overall === 0 ? "dialog-ok-apply" : "dialog-warning"
                isMask: true
                color: sec.overall === 0 ? "#7EE2A8" : (sec.overall === 1 ? "#F2CC60" : "#FF9B94")
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                GText {
                    id: headline
                    Layout.fillWidth: true
                    text: !sec.loaded ? "Checking your device…" : sec.overall === 0 ? "Your device is protected" : sec.overall === 1 ? "Action recommended" : "Action needed"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.5
                    font.weight: Font.DemiBold
                }
                GText {
                    id: sub
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    dim: true
                    text: sec.overall === 0 ? "Nothing needs your attention. New files are checked as they arrive, on this PC only."
                        : sec.overall === 1 ? "Your device is working, but a few settings below could be stronger."
                        : "Something below is turned off. Open the tile marked Action needed to fix it."
                }
            }
        }
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
            level: sec.lvAv
            details: (sec.v("av_last", "never") === "never" ? "No scan yet." : "Last scan: " + sec.v("av_last") + (sec.v("av_result") === "found" ? " · " + sec.v("av_found") + " found" : sec.v("av_result") === "clean" ? " · no threats" : ""))
                     + "\nDefinitions: " + (sec.v("av_defs") === "none" ? "No virus definitions — press Update (Scan now downloads them)" : sec.v("av_defs"))
                     + " · In quarantine: " + sec.v("av_quarantine", "0")
                     + "\nDefinitions download only when you click a scan button. New files in Downloads are checked with the definitions you have"
                     + (sec.v("dl_watch") === "on" ? "." : " (off).") + " Games are never scanned. Right-click any file: Scan with Mountain Security."
            tech: "Scanner: ClamAV, on demand only. Download checks: " + (sec.v("dl_watch") === "on" ? "on" : "off") + "."
            buttons: [
                GlassButton { text: "Quick scan"; highlighted: true; enabled: sec.running === ""; onClicked: sec.start("scan", sec.helper + " scan quick") },
                GlassButton { text: "Full scan"; enabled: sec.running === ""; onClicked: sec.start("scan", sec.helper + " scan full") },
                GlassButton { text: "Custom scan"; enabled: sec.running === ""; onClicked: sec.start("scan", "d=$(kdialog --getexistingdirectory \"$HOME\") || { echo av_result=cancelled; exit 0; }; " + sec.helper + " scan \"$d\"") },
                GlassButton { text: "Open quarantine"; onClicked: app.run("dolphin \"$HOME/.local/share/mountain/quarantine\"") }
            ]
        }
        SecurityCard {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            iconName: "view-visible"
            title: "Active Protection"
            level: sec.lvAp
            details: sec.a("ap") === "on"
                     ? "On. Files checked today: " + sec.a("ap_checked_today", "0") + " · Threats blocked: " + sec.a("ap_threats", "0")
                       + "\nNew files in Downloads, Desktop, Documents and USB drives are checked as they arrive. When you extract an archive, you get one result."
                     : "Off. New files are not checked until you scan by hand."
            tech: "Watcher: inotify + ClamAV in a sandboxed low-priority unit that exits when done."
            buttons: [
                GlassButton { visible: sec.a("ap") !== "on"; text: "Turn on"; highlighted: true; enabled: sec.running === ""; onClicked: sec.start("fix", "/usr/libexec/mountain-protect on") },
                GlassButton { text: "Open Active Protection"; onClicked: app.page = "protection" }
            ]
        }
        SecurityCard {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            iconName: "document-revert"
            title: "Ransomware protection"
            level: sec.v("snapshots") === "off" ? 1 : 0
            details: sec.v("snapshots") === "off"
                     ? "Off: Previous versions need the standard disk layout the installer creates."
                     : "Previous versions: " + sec.v("snapshots", "0") + " saved copies of your files, taken every hour. Newest: " + (sec.v("snapshot_last") || "none yet")
                       + "\nPrograms can't change or delete them. To restore, copy a file back from File Explorer › Previous versions."
            tech: "Read-only Btrfs snapshots of /var/home in /var/home/.snapshots."
            buttons: [
                GlassButton { text: "Open Previous versions"; enabled: sec.v("snapshots") !== "off"; onClicked: app.run("dolphin /var/home/.snapshots") },
                GlassButton { text: "Save a version now"; enabled: sec.v("snapshots") !== "off" && sec.running === ""; onClicked: sec.start("snapshot", "systemctl start mountain-snapshot.service") }
            ]
        }
        SecurityCard {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            iconName: "network-firewall"
            title: "Firewall & network protection"
            level: sec.lvFw
            details: sec.v("fw") === "on"
                     ? "Firewall is on. Apps allowed through: " + (sec.list("fw_app").filter(x => x.split(":")[1] === "yes").map(x => x.split(":").slice(2).join(":")).join(", ") || "none") + "."
                     : "Firewall is off. Other devices could reach apps on this PC."
            details2: sec.v("fw") === "on" ? "Network profile: " + (sec.v("fw_profile") === "home" ? "Private (other PCs can find this one)" : "Public (hidden from other devices)") : ""
            tech: sec.v("fw") === "on" ? "firewalld zone: " + sec.v("fw_zone") + ". Open services: " + (sec.v("fw_open") || "none") + "." : ""
            buttons: [
                GlassButton { visible: sec.v("fw") !== "on"; text: "Turn on"; highlighted: true; onClicked: sec.start("fix", "systemctl start firewalld") },
                GlassButton { visible: sec.v("fw") === "on"; text: "Private network"; highlighted: sec.v("fw_profile") === "home"; enabled: sec.running === ""; onClicked: sec.start("fix", sec.helper + " profile home") },
                GlassButton { visible: sec.v("fw") === "on"; text: "Public network"; highlighted: sec.v("fw_profile") !== "home"; enabled: sec.running === ""; onClicked: sec.start("fix", sec.helper + " profile public") }
            ]
        }
        SecurityCard {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            iconName: "preferences-security"
            title: "App & browser protection"
            level: sec.lvApp
            details: "Apps from the App Store run in their own protected space. Chat, browser and office apps can't see your home folder: you pick files in the Open dialog. Game launchers keep their own access."
            tech: "Flatpak sandbox tightened for " + sec.v("flatpak_tight", "?") + " apps."
            buttons: []
        }
        SecurityCard {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            iconName: "cpu"
            title: "Device security"
            level: sec.lvDev
            details: "Secure Boot: " + (sec.v("sb") === "on" ? "on" : sec.v("sb") === "off" ? "off" : "not supported")
                     + " · TPM: " + (sec.v("tpm") === "yes" ? "yes" : "no")
                     + " · Security policy: " + (sec.v("selinux") === "Enforcing" ? "on" : "off")
                     + "\nDriver lockdown: " + (sec.v("lockdown") === "none" ? "off (so game drivers load)" : sec.v("lockdown") === "integrity" || sec.v("lockdown") === "confidentiality" ? "on" : "not available") + " · Disk encryption: " + (sec.v("encrypted") === "yes" ? "on" : "off")
                     + "\nUSB protection: " + (sec.v("usb") === "on" ? "on: new USB devices are blocked until you allow them" : "off (turning it on keeps everything plugged in now working)")
            tech: "SELinux: " + sec.v("selinux", "?") + " · Kernel lockdown: " + sec.v("lockdown", "?") + " · USB protection: usbguard"
            buttons: [
                GlassButton { text: sec.v("usb") === "on" ? "Turn off USB protection" : "Turn on USB protection"; enabled: sec.running === ""; onClicked: sec.start("fix", sec.helper + " usb " + (sec.v("usb") === "on" ? "off" : "on")) },
                GlassButton { visible: sec.v("selinux") !== "Enforcing"; text: "Turn on security policy"; highlighted: true; onClicked: sec.start("fix", "pkexec setenforce 1") },
                GlassButton { visible: sec.v("sb") === "off" || sec.v("encrypted") === "no"; text: "How to turn these on"; onClicked: Qt.openUrlExternally(sec.guide + "#secure-boot-and-disk-encryption") }
            ]
        }
        SecurityCard { // Windows Security > Protection history: newest first
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            iconName: "view-history"
            title: "Protection history"
            level: 0
            details: sec.list("av_history").length === 0 ? "No recent protection actions."
                     : sec.list("av_history").slice().reverse().join("\n")
            tech: "Scans, threats moved to quarantine and files you allowed or restored. In quarantine now: " + sec.v("av_quarantine", "0") + "."
            buttons: [
                GlassButton { text: "See all"; onClicked: app.page = "protection" },
                GlassButton { text: "Open quarantine"; onClicked: app.run("dolphin \"$HOME/.local/share/mountain/quarantine\"") }
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
                GlassButton { text: "Go back to the previous version"; enabled: sec.v("rollback") === "yes" && sec.running === ""; onClicked: sec.start("rollback", "/usr/libexec/mountain-security rollback") },
                GlassButton { text: "Reset this PC"; enabled: sec.running === ""; onClicked: sec.start("fix", "/usr/libexec/mountain-security reset") },
                GlassButton { visible: sec.v("windows") === "yes"; text: "Restart into Windows"; onClicked: app.run("/usr/libexec/mountain-windows-boot go --no-restart && dbus-send --session --type=method_call --dest=org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptReboot") }
            ]
        }
        SecurityCard {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            iconName: "system-users"
            title: "Account protection"
            level: sec.v("password") === "none" ? 2 : (sec.v("screenlock") === "false" ? 1 : 0)
            details: "Password: " + (sec.v("password") === "set" ? "set" : sec.v("password") === "none" ? "none — anyone can use this PC" : "unknown")
                     + " · Screen lock: " + (sec.v("screenlock") === "false" ? "off" : "on, after " + sec.v("autolock_min", "5") + " minutes")
                     + "\nAdmin tasks always ask for your password."
            buttons: [
                GlassButton { visible: sec.v("password") === "none"; text: "Set a password"; highlighted: true; onClicked: app.page = "youraccount" },
                GlassButton { visible: sec.v("screenlock") === "false"; text: "Turn on screen lock"; onClicked: sec.start("fix", "kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock true") }
            ]
        }
    }

    GText {
        Layout.topMargin: 14
        visible: sec.list("fw_app").length > 0
        text: "Allow an app through the firewall"
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.25
        font.weight: Font.DemiBold
    }
    Repeater {
        model: sec.list("fw_app") // service:yes|no:name
        delegate: GlassCard {
            required property string modelData
            readonly property var f: modelData.split(":")
            Layout.fillWidth: true
            padding: 12
            RowLayout {
                Layout.fillWidth: true
                GText { Layout.fillWidth: true; text: f.slice(2).join(":") }
                GText { text: f[1] === "yes" ? "Allowed" : "Blocked"; dim: true }
                GlassButton {
                    text: f[1] === "yes" ? "Block" : "Allow"
                    enabled: sec.running === ""
                    Accessible.name: text + " " + f.slice(2).join(":")
                    onClicked: sec.start("fix", sec.helper + " allow " + f[0] + (f[1] === "yes" ? " off" : " on"))
                }
            }
        }
    }
    GText {
        Layout.topMargin: 14
        visible: sec.list("av_q").length > 0
        text: "Quarantine"
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.25
        font.weight: Font.DemiBold
    }
    Repeater {
        model: sec.list("av_q")
        delegate: GlassCard {
            required property string modelData
            Layout.fillWidth: true
            padding: 12
            RowLayout {
                Layout.fillWidth: true
                GText { Layout.fillWidth: true; text: modelData }
                GlassButton { text: "Restore"; Accessible.name: "Restore " + modelData; onClicked: sec.start("fix", sec.helper + " quarantine-restore " + sec.q(modelData)) }
                GlassButton { text: "Delete"; Accessible.name: "Delete " + modelData; onClicked: sec.start("fix", sec.helper + " quarantine-delete " + sec.q(modelData)) }
            }
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
