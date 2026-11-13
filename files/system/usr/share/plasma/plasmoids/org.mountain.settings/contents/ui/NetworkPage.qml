import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.networkmanagement as PlasmaNM

// Network & internet as in Windows 11: a status card for the connection in use, then one card row per page.
// Live state from plasma-nm (the same objects and calls as the quick-settings tiles and plasma-nm's Toolbar.qml);
// without the module main.qml shows ListPage instead. No polling: data usage is read on open and when connections change.
ColumnLayout {
    id: net
    spacing: 6

    PlasmaNM.NetworkStatus { id: netStatus }
    PlasmaNM.ConnectionIcon { id: connIcon; connectivity: netStatus.connectivity }
    PlasmaNM.EnabledConnections { id: nmEnabled }
    PlasmaNM.AvailableDevices { id: devices }
    PlasmaNM.Handler { id: handler }

    // shortcut: parses plasma-nm's "Type: Connected to Name" lines (English UI); in another language the hero shows the whole line
    readonly property var lines: netStatus.activeConnections.split("\n")
    readonly property string heroLine: lines[0] || ""
    readonly property bool online: heroLine.indexOf(": ") > 0
    readonly property bool airplane: PlasmaNM.Configuration.airplaneModeEnabled
    property string usage: ""

    function typeOf(l) { return l.slice(0, l.indexOf(": ")); }
    function statusOf(l) { return l.slice(l.indexOf(": ") + 2); }
    function nameOf(l) { return statusOf(l).replace(/^(Connected|Connecting) to /, "").replace(/ \((no connectivity|limited connectivity|log in required)\)$/, ""); }
    function lineFor(re) { return lines.find(l => l.indexOf(": ") > 0 && re.test(typeOf(l))) || ""; }

    function sub(it) {
        const l = it.net === "wifi" ? lineFor(/Wi-?Fi|Wireless/i) : it.net === "ethernet" ? lineFor(/Ethernet|Wired/i) : it.net === "vpn" ? lineFor(/VPN|WireGuard/i) : "";
        switch (it.net) {
        case "wifi": return !devices.wirelessDeviceAvailable ? "No Wi-Fi adapter" : airplane ? "Off: airplane mode is on" : !nmEnabled.wirelessEnabled ? "Off" : l ? statusOf(l) : "Not connected";
        case "ethernet": return !devices.wiredDeviceAvailable ? "No Ethernet adapter" : l ? statusOf(l) : "Not connected";
        case "vpn": return l ? statusOf(l) : it.d;
        case "hotspot": return handler.hotspotActive ? "On: sharing as \"" + PlasmaNM.Configuration.hotspotName + "\""
                             : !devices.wirelessDeviceAvailable ? "Needs a Wi-Fi adapter"
                             : !handler.hotspotSupported ? "Turn on Wi-Fi and disconnect from it (or add a second adapter) to share" : it.d;
        default: return it.d;
        }
    }
    function hasSwitch(it) { return it.net === "airplane" || ((it.net === "wifi" || it.net === "hotspot") && devices.wirelessDeviceAvailable); }
    function isOn(it) { return it.net === "wifi" ? (nmEnabled.wirelessEnabled && !airplane) : it.net === "hotspot" ? handler.hotspotActive : airplane; }
    function canSwitch(it) { return it.net === "wifi" ? (nmEnabled.wirelessHwEnabled && !airplane) : it.net === "hotspot" ? (handler.hotspotSupported || handler.hotspotActive) : true; }
    function flip(it) {
        if (it.net === "wifi") {
            handler.enableWireless(!nmEnabled.wirelessEnabled);
        } else if (it.net === "hotspot") {
            if (PlasmaNM.Configuration.hotspotConnectionPath) handler.stopHotspot(); else handler.createHotspot();
        } else {
            const on = !airplane;
            handler.enableAirplaneMode(on);
            PlasmaNM.Configuration.airplaneModeEnabled = on;
        }
    }

    // bytes on the default-route interface since it came up (no user text in the command)
    readonly property string bytesCmd: "d=$(ip route show default 2>/dev/null | awk '{print $5; exit}'); [ -n \"$d\" ] && cat \"/sys/class/net/$d/statistics/rx_bytes\" \"/sys/class/net/$d/statistics/tx_bytes\""
    function readUsage() { exec.connectSource(bytesCmd + " # " + Date.now()); }
    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            const n = (data["stdout"] || "").trim().split(/\s+/).map(Number).filter(x => x >= 0);
            const b = n.length === 2 ? n[0] + n[1] : -1;
            net.usage = b < 0 ? "" : (b >= 1e9 ? (b / 1e9).toFixed(1) + " GB" : Math.round(b / 1e6) + " MB") + " since you turned on this PC";
        }
    }
    onHeroLineChanged: readUsage()
    Component.onCompleted: readUsage()

    GText {
        Layout.topMargin: 6
        Layout.bottomMargin: 14
        Layout.fillWidth: true
        text: app.currentCategory.name
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2
        font.weight: Font.DemiBold
    }

    // Status card: the connection in use, Properties and Data usage
    GlassCard {
        Layout.fillWidth: true
        Layout.bottomMargin: 10
        padding: 12
        GridLayout {
            Layout.fillWidth: true
            columns: width > 640 ? 3 : 1
            columnSpacing: 8
            rowSpacing: 4
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.leftMargin: 6
                spacing: 14
                Kirigami.Icon {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    source: connIcon.connectionIcon
                    fallback: "network-wired"
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    GText {
                        Layout.fillWidth: true
                        text: net.online ? net.nameOf(net.heroLine) : "Not connected"
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                        font.weight: Font.DemiBold
                    }
                    GText {
                        Layout.fillWidth: true
                        dim: true
                        text: net.online ? net.typeOf(net.heroLine) + " · " + net.statusOf(net.heroLine).replace(" to " + net.nameOf(net.heroLine), "") : net.heroLine
                    }
                }
            }
            SettingRow {
                Layout.preferredWidth: 1
                text: "Properties"
                description: net.online ? net.typeOf(net.heroLine) : "Adapters and connections"
                iconName: "document-properties"
                onClicked: app.openKcm("kcm_networkmanagement")
            }
            SettingRow {
                Layout.preferredWidth: 1
                text: "Data usage"
                description: net.usage || "Not connected"
                iconName: "network-transmit-receive"
                onClicked: app.run("kstart --application org.kde.plasma-systemmonitor")
            }
        }
    }

    Repeater {
        model: app.currentCategory.items
        delegate: GlassCard {
            required property var modelData
            Layout.fillWidth: true
            SettingRow {
                text: modelData.t
                description: net.sub(modelData)
                iconName: modelData.i
                onClicked: modelData.net === "airplane" ? net.flip(modelData) : app.openItem(modelData)
                trailing: [
                    GText {
                        visible: net.hasSwitch(modelData)
                        text: net.isOn(modelData) ? "On" : "Off"
                    },
                    PillSwitch {
                        visible: net.hasSwitch(modelData)
                        enabled: net.canSwitch(modelData)
                        opacity: enabled ? 1 : 0.5
                        text: modelData.t
                        checked: net.isOn(modelData)
                        onClicked: net.flip(modelData)
                    }
                ]
            }
        }
    }
}
