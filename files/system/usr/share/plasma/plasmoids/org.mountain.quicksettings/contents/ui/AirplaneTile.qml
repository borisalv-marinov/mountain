// Airplane mode on plasma-nm (same calls as plasma-nm applet/main.qml planeAction).
import QtQuick
import org.kde.plasma.networkmanagement as PlasmaNM

Tile {
    PlasmaNM.Handler { id: handler }

    checked: PlasmaNM.Configuration.airplaneModeEnabled
    text: i18n("Airplane mode")
    iconName: checked ? "network-flightmode-on" : "network-flightmode-off"
    onToggled: {
        const on = !checked;
        handler.enableAirplaneMode(on);
        PlasmaNM.Configuration.airplaneModeEnabled = on;
    }
}
