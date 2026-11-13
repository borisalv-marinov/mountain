// Wi-Fi tile on plasma-nm (same calls as plasma-nm applet/Toolbar.qml).
import QtQuick
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.kcmutils as KCMUtils

Tile {
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
    onArrowClicked: KCMUtils.KCMLauncher.openSystemSettings("kcm_networkmanagement")
}
