// Wi-Fi tile on plasma-nm (same calls as plasma-nm applet/Toolbar.qml).
import QtQuick
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.plasma.plasma5support as P5Support

Tile {
    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => disconnectSource(source)
    }
    PlasmaNM.EnabledConnections { id: enabledConnections }
    PlasmaNM.AvailableDevices { id: availableDevices }
    PlasmaNM.Handler { id: handler }

    split: true
    available: availableDevices.wirelessDeviceAvailable && enabledConnections.wirelessHwEnabled
               && !PlasmaNM.Configuration.airplaneModeEnabled
    checked: available && enabledConnections.wirelessEnabled
    text: i18n("Wi-Fi")
    iconName: checked ? "network-wireless-symbolic" : "network-wireless-disconnected-symbolic"
    onToggled: handler.enableWireless(!checked)
    onArrowClicked: exec.connectSource("/usr/libexec/mountain-settings-open network >/dev/null 2>&1 &")
}
