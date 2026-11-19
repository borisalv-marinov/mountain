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
    readonly property int lvAv: v("av_result") === "found" ? 1 : (v("av_defs") === "none" ? 1 : 0)
    readonly property int nUnv: Array.isArray(ap.ap_unverified) ? ap.ap_unverified.length : 0
    readonly property int lvAp: a("ap") !== "on" ? 2 : (v("av_defs") === "none" ? 2 : (nUnv > 0 ? 1 : 0)) // same rule as the Active Protection page
    readonly property int lvFw: v("fw") === "on" ? 0 : 2
    readonly property int lvApp: ((t) => t.includes("/") && t.split("/")[0] === t.split("/")[1])(v("flatpak_tight")) ? 0 : 1 // every shipped app tightened (n/n)
    readonly property int lvDev: v("selinux") !== "Enforcing" ? 2 : ((v("sb") === "off" || v("encrypted") === "no") ? 1 : 0)
    readonly property int lvSnap: v("snapshots") === "off" ? 1 : 0
    readonly property int lvUpd: v("rollback") === "yes" ? 0 : 1
    readonly property int lvAcc: v("password") === "none" ? 2 : (v("screenlock") === "false" ? 1 : 0)
    readonly property bool loaded: s.fw !== undefined && ap.ap !== undefined
    readonly property int overall: !loaded ? 0 : Math.max(lvAv, lvAp, lvFw, lvApp, lvDev, lvSnap, lvUpd, lvAcc) // every card shown, so banner and cards agree
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
                const m = { fw_app: [], av_history: [], av_q: [], ap_unverified: [] };
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
                         : out.indexOf("av_result=found") >= 0 ? i18n("Threats found. They were moved to quarantine, where they can't run.")
                         : out.indexOf("av_result=clean") >= 0 ? i18n("Scan finished: no threats found.")
                         : out.indexOf("av_result=no-definitions") >= 0 ? i18n("No virus definitions yet. Connect to the internet and press Scan now to download them.")
                         : i18n("The scan could not finish. Try again, or see Active Protection's log.");
            } else if (sec.running === "rollback") {
                sec.note = data["exit code"] === 0 ? i18n("Done. Restart your PC to go back to the previous version.") : i18n("Going back was cancelled.");
            }
            sec.running = "";
            sec.refresh();
        }
    }
    Component.onCompleted: refresh()

    GText {
        Layout.topMargin: 6
        Layout.bottomMargin: 6
        text: i18n("Privacy & security")
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
                    text: !sec.loaded ? i18n("Checking your device…") : sec.overall === 0 ? i18n("Your device is protected") : sec.overall === 1 ? i18n("Action recommended") : i18n("Action needed")
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.5
                    font.weight: Font.DemiBold
                }
                GText {
                    id: sub
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    dim: true
                    text: sec.overall === 0 ? i18n("Nothing needs your attention. New files are checked as they arrive, on this PC only.")
                        : sec.overall === 1 ? i18n("Your device is working, but a few settings below could be stronger.")
                        : i18n("Something below is turned off. Open the tile marked Action needed to fix it.")
                }
            }
        }
    }
    GText {
        Layout.fillWidth: true
        visible: sec.note !== "" || sec.running !== ""
        text: sec.running === "scan" ? i18n("Scanning your files… Virus definitions download first, then the scan runs at low priority, so games stay smooth.")
            : sec.running !== "" ? i18n("Working…") : sec.note
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
            title: i18n("Virus & threat protection")
            level: sec.lvAv
            details: (sec.v("av_last", "never") === "never" ? i18n("No scan yet.") : i18n("Last scan: %1", sec.v("av_last")) + (sec.v("av_result") === "found" ? i18n(" · %1 found", sec.v("av_found")) : sec.v("av_result") === "clean" ? i18n(" · no threats") : ""))
                     + "\n" + i18n("Definitions: %1", sec.v("av_defs") === "none" ? i18n("No virus definitions — press Update (Scan now downloads them)") : sec.v("av_defs"))
                     + i18n(" · In quarantine: %1", sec.v("av_quarantine", "0"))
                     + "\n" + (sec.v("dl_watch") === "on" ? i18n("Definitions download only when you click a scan button. New files in Downloads are checked with the definitions you have. Games are never scanned. Right-click any file: Scan with Mountain Security.") : i18n("Definitions download only when you click a scan button. New files in Downloads are checked with the definitions you have (off). Games are never scanned. Right-click any file: Scan with Mountain Security."))
            tech: sec.v("dl_watch") === "on" ? i18n("Scanner: ClamAV, on demand only. Download checks: on.") : i18n("Scanner: ClamAV, on demand only. Download checks: off.")
            buttons: [
                GlassButton { text: i18n("Update"); highlighted: true; visible: sec.v("av_defs") === "none"; enabled: sec.running === ""; onClicked: sec.start("update", sec.helper + " update") },
                GlassButton { text: i18n("Quick scan"); highlighted: true; enabled: sec.running === ""; onClicked: sec.start("scan", sec.helper + " scan quick") },
                GlassButton { text: i18n("Full scan"); enabled: sec.running === ""; onClicked: sec.start("scan", sec.helper + " scan full") },
                GlassButton { text: i18n("Custom scan"); enabled: sec.running === ""; onClicked: sec.start("scan", "d=$(kdialog --getexistingdirectory \"$HOME\") || { echo av_result=cancelled; exit 0; }; " + sec.helper + " scan \"$d\"") },
                GlassButton { text: i18n("Open quarantine"); onClicked: app.run("dolphin \"$HOME/.local/share/mountain/quarantine\"") }
            ]
        }
        SecurityCard {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            iconName: "view-visible"
            title: i18n("Active Protection")
            level: sec.lvAp
            details: sec.a("ap") === "on"
                     ? i18n("On. Files checked today: %1 · Threats blocked: %2", sec.a("ap_checked_today", "0"), sec.a("ap_threats", "0"))
                       + (sec.nUnv > 0 ? "\n" + i18n("%1 files to review", sec.nUnv) : "")
                       + "\n" + i18n("New files in Downloads, Desktop, Documents and USB drives are checked as they arrive. When you extract an archive, you get one result.")
                     : i18n("Off. New files are not checked until you scan by hand.")
            tech: i18n("Watcher: inotify + ClamAV in a sandboxed low-priority unit that exits when done.")
            buttons: [
                GlassButton { visible: sec.a("ap") !== "on"; text: i18n("Turn on"); highlighted: true; enabled: sec.running === ""; onClicked: sec.start("fix", "/usr/libexec/mountain-protect on") },
                GlassButton { text: i18n("Open Active Protection"); onClicked: app.page = "protection" }
            ]
        }
        SecurityCard {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            iconName: "document-revert"
            title: i18n("Ransomware protection")
            level: sec.lvSnap
            details: sec.v("snapshots") === "off"
                     ? i18n("Off: Previous versions need the standard disk layout the installer creates.")
                     : i18n("Previous versions: %1 saved copies of your files, taken every hour. Newest: %2", sec.v("snapshots", "0"), sec.v("snapshot_last") || i18n("none yet"))
                       + "\n" + i18n("Programs can't change or delete them. To restore, copy a file back from File Explorer › Previous versions.")
            tech: i18n("Read-only Btrfs snapshots of /var/home in /var/home/.snapshots.")
            buttons: [
                GlassButton { text: i18n("Open Previous versions"); enabled: sec.v("snapshots") !== "off"; onClicked: app.run("dolphin /var/home/.snapshots") },
                GlassButton { text: i18n("Save a version now"); enabled: sec.v("snapshots") !== "off" && sec.running === ""; onClicked: sec.start("snapshot", "systemctl start mountain-snapshot.service") }
            ]
        }
        SecurityCard {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            iconName: "firewall-applet"
            title: i18n("Firewall & network protection")
            level: sec.lvFw
            details: sec.v("fw") === "on"
                     ? i18n("Firewall is on. Apps allowed through: %1.", sec.list("fw_app").filter(x => x.split(":")[1] === "yes").map(x => x.split(":").slice(2).join(":")).join(", ") || i18n("none"))
                     : i18n("Firewall is off. Other devices could reach apps on this PC.")
            details2: sec.v("fw") === "on" ? i18n("Network profile: %1", sec.v("fw_profile") === "home" ? i18n("Private (other PCs can find this one)") : i18n("Public (hidden from other devices)")) : ""
            tech: sec.v("fw") === "on" ? i18n("firewalld zone: %1. Open services: %2.", sec.v("fw_zone"), sec.v("fw_open") || i18n("none")) : ""
            buttons: [
                GlassButton { visible: sec.v("fw") !== "on"; text: i18n("Turn on"); highlighted: true; onClicked: sec.start("fix", "systemctl start firewalld") },
                GlassButton { visible: sec.v("fw") === "on"; text: i18n("Private network"); highlighted: sec.v("fw_profile") === "home"; enabled: sec.running === ""; onClicked: sec.start("fix", sec.helper + " profile home") },
                GlassButton { visible: sec.v("fw") === "on"; text: i18n("Public network"); highlighted: sec.v("fw_profile") !== "home"; enabled: sec.running === ""; onClicked: sec.start("fix", sec.helper + " profile public") }
            ]
        }
        SecurityCard {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            iconName: "preferences-security"
            title: i18n("App & browser protection")
            level: sec.lvApp
            details: i18n("Apps from the App Store run in their own protected space. Chat, browser and office apps can't see your home folder: you pick files in the Open dialog. Game launchers keep their own access.")
            tech: i18n("Flatpak sandbox tightened for %1 apps.", sec.v("flatpak_tight", "?"))
            buttons: []
        }
        SecurityCard {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            iconName: "computer"
            title: i18n("Device security")
            level: sec.lvDev
            details: i18n("Secure Boot: %1", sec.v("sb") === "on" ? i18n("on") : sec.v("sb") === "off" ? i18n("off") : i18n("not supported"))
                     + i18n(" · TPM: %1", sec.v("tpm") === "yes" ? i18n("yes") : i18n("no"))
                     + i18n(" · Security policy: %1", sec.v("selinux") === "Enforcing" ? i18n("on") : i18n("off"))
                     + "\n" + i18n("Driver lockdown: %1", sec.v("lockdown") === "none" ? i18n("off (so game drivers load)") : sec.v("lockdown") === "integrity" || sec.v("lockdown") === "confidentiality" ? i18n("on") : i18n("not available")) + i18n(" · Disk encryption: %1", sec.v("encrypted") === "yes" ? i18n("on") : i18n("off"))
                     + "\n" + i18n("USB protection: %1", sec.v("usb") === "on" ? i18n("on: new USB devices are blocked until you allow them") : i18n("off (turning it on keeps everything plugged in now working)"))
            tech: i18n("SELinux: %1 · Kernel lockdown: %2 · USB protection: usbguard", sec.v("selinux", "?"), sec.v("lockdown", "?"))
            buttons: [
                GlassButton { text: sec.v("usb") === "on" ? i18n("Turn off USB protection") : i18n("Turn on USB protection"); enabled: sec.running === ""; onClicked: sec.start("fix", sec.helper + " usb " + (sec.v("usb") === "on" ? "off" : "on")) },
                GlassButton { visible: sec.v("selinux") !== "Enforcing"; text: i18n("Turn on security policy"); highlighted: true; onClicked: sec.start("fix", "pkexec setenforce 1") },
                GlassButton { visible: sec.v("sb") === "off" || sec.v("encrypted") === "no"; text: i18n("How to turn these on"); onClicked: Qt.openUrlExternally(sec.guide + "#secure-boot-and-disk-encryption") }
            ]
        }
        SecurityCard { // Windows Security > Protection history: newest first
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            iconName: "view-history"
            title: i18n("Protection history")
            level: 0
            details: sec.list("av_history").length === 0 ? i18n("No recent protection actions.")
                     : sec.list("av_history").slice().reverse().join("\n")
            tech: i18n("Scans, threats moved to quarantine and files you allowed or restored. In quarantine now: %1.", sec.v("av_quarantine", "0"))
            buttons: [
                GlassButton { text: i18n("See all"); onClicked: app.page = "protection" },
                GlassButton { text: i18n("Open quarantine"); onClicked: app.run("dolphin \"$HOME/.local/share/mountain/quarantine\"") }
            ]
        }
        SecurityCard {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            iconName: "system-software-update"
            title: i18n("Updates & recovery")
            level: sec.lvUpd
            details: i18n("This version: %1", sec.v("upd_time", "?")) + (sec.v("upd_signed") === "yes" ? i18n(" · signed updates") : "")
                     + "\n" + (sec.v("rollback") === "yes" ? i18n("The previous version is kept: you can go back at any time, here or in the boot menu.") : i18n("No previous version yet (it appears after your first update)."))
            buttons: [
                GlassButton { text: i18n("Check for updates"); onClicked: app.run("kstart --application io.github.rfrench3.bazzite-updater") },
                GlassButton { text: i18n("Go back to the previous version"); enabled: sec.v("rollback") === "yes" && sec.running === ""; onClicked: sec.start("rollback", "/usr/libexec/mountain-security rollback") },
                GlassButton { text: i18n("Reset this PC"); enabled: sec.running === ""; onClicked: sec.start("fix", "/usr/libexec/mountain-security reset") },
                GlassButton { visible: sec.v("windows") === "yes"; text: i18n("Restart into Windows"); onClicked: app.run("/usr/libexec/mountain-windows-boot go --no-restart && dbus-send --session --type=method_call --dest=org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptReboot") }
            ]
        }
        SecurityCard {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            iconName: "system-users"
            title: i18n("Account protection")
            level: sec.lvAcc
            details: i18n("Password: %1", sec.v("password") === "set" ? i18n("set") : sec.v("password") === "none" ? i18n("none — anyone can use this PC") : i18n("unknown"))
                     + i18n(" · Screen lock: %1", sec.v("screenlock") === "false" ? i18n("off") : i18n("on, after %1 minutes", sec.v("autolock_min", "5")))
                     + "\n" + i18n("Admin tasks always ask for your password.")
            buttons: [
                GlassButton { visible: sec.v("password") === "none"; text: i18n("Set a password"); highlighted: true; onClicked: app.page = "youraccount" },
                GlassButton { visible: sec.v("screenlock") === "false"; text: i18n("Turn on screen lock"); onClicked: sec.start("fix", "kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock true") }
            ]
        }
    }

    GText {
        Layout.topMargin: 14
        visible: sec.list("fw_app").length > 0
        text: i18n("Allow an app through the firewall")
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
                GText { text: f[1] === "yes" ? i18n("Allowed") : i18n("Blocked"); dim: true }
                GlassButton {
                    text: f[1] === "yes" ? i18n("Block") : i18n("Allow")
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
        text: i18n("Quarantine")
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
                GlassButton { text: i18n("Restore"); Accessible.name: i18n("Restore %1", modelData); onClicked: sec.start("fix", sec.helper + " quarantine-restore " + sec.q(modelData)) }
                GlassButton { text: i18n("Delete"); Accessible.name: i18n("Delete %1", modelData); onClicked: sec.start("fix", sec.helper + " quarantine-delete " + sec.q(modelData)) }
            }
        }
    }

    GText {
        Layout.topMargin: 14
        text: i18n("Permissions")
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
