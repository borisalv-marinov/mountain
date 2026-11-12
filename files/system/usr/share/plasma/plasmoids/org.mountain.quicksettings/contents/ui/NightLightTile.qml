// Night light: state from KWin's org.kde.KWin.NightLight (as powerdevil applets/brightness/NightLightItem.qml),
// toggle = kwinrc [NightColor] Active (kwin src/plugins/nightlight/nightlightsettings.kcfg); --notify reaches
// KWin's KConfigWatcher, reconfigure is a fallback.
import QtQuick
import org.kde.plasma.workspace.dbus as DBus
import org.kde.plasma.plasma5support as P5Support

Tile {
    DBus.Properties {
        id: nightLight
        busType: DBus.BusType.Session
        service: "org.kde.KWin.NightLight"
        path: "/org/kde/KWin/NightLight"
        iface: "org.kde.KWin.NightLight"
    }
    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => { disconnectSource(source); nightLight.updateAll(); }
    }

    available: Boolean(nightLight.properties?.available)
    checked: Boolean(nightLight.properties?.enabled)
    text: available ? i18n("Night light") : i18n("Night light unavailable")
    iconName: checked ? "redshift-status-on" : "redshift-status-off"
    onToggled: exec.connectSource("kwriteconfig6 --file kwinrc --group NightColor --key Active --type bool --notify "
        + (checked ? "false" : "true")
        + " && dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure")
}
