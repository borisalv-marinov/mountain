// Energy saver = power profile "power-saver" on net.hadess.PowerProfiles (power-profiles-daemon / tuned-ppd).
// DBus.Properties follows PropertiesChanged, so no polling; writing a key calls Properties.Set.
import QtQuick
import org.kde.plasma.workspace.dbus as DBus

Tile {
    DBus.Properties {
        id: profiles
        busType: DBus.BusType.System
        service: "net.hadess.PowerProfiles"
        path: "/net/hadess/PowerProfiles"
        iface: "net.hadess.PowerProfiles"
    }

    readonly property string active: profiles.properties?.ActiveProfile ?? ""

    available: active !== ""
    checked: active === "power-saver"
    text: available ? i18n("Energy saver") : i18n("Energy saver unavailable")
    iconName: "battery-profile-powersave-symbolic"
    onToggled: profiles.properties.ActiveProfile = checked ? "balanced" : "power-saver"
}
