// Bluetooth tile on BluezQt (same calls as bluedevil src/applet/qml/main.qml).
import QtQuick
import org.kde.bluezqt as BluezQt
import org.kde.plasma.plasma5support as P5Support

Tile {
    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => disconnectSource(source)
    }
    split: true
    available: BluezQt.Manager.bluetoothBlocked || BluezQt.Manager.adapters.length > 0
    checked: BluezQt.Manager.bluetoothOperational
    text: i18n("Bluetooth")
    iconName: "preferences-system-bluetooth-symbolic"
    onToggled: {
        const enable = !checked;
        BluezQt.Manager.bluetoothBlocked = !enable;
        BluezQt.Manager.adapters.forEach(adapter => { adapter.powered = enable; });
    }
    onArrowClicked: exec.connectSource("/usr/libexec/mountain-settings-open bluetooth >/dev/null 2>&1 &")
}
