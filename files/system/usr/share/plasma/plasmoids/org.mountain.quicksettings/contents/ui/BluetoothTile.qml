// Bluetooth tile on BluezQt (same calls as bluedevil src/applet/qml/main.qml).
import QtQuick
import org.kde.bluezqt as BluezQt
import org.kde.kcmutils as KCMUtils

Tile {
    split: true
    available: BluezQt.Manager.bluetoothBlocked || BluezQt.Manager.adapters.length > 0
    checked: BluezQt.Manager.bluetoothOperational
    text: available ? i18n("Bluetooth") : i18n("Bluetooth unavailable")
    iconName: "preferences-system-bluetooth-symbolic"
    onToggled: {
        const enable = !checked;
        BluezQt.Manager.bluetoothBlocked = !enable;
        BluezQt.Manager.adapters.forEach(adapter => { adapter.powered = enable; });
    }
    onArrowClicked: KCMUtils.KCMLauncher.openSystemSettings("kcm_bluetooth")
}
