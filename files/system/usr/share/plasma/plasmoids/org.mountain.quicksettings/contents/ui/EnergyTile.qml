// Energy saver = power profile "power-saver" on net.hadess.PowerProfiles (power-profiles-daemon / tuned-ppd).
// DBus.Properties follows PropertiesChanged, so no polling; writing a key calls Properties.Set.
import QtQuick
import org.kde.plasma.workspace.dbus as DBus
import org.kde.plasma.plasma5support as P5Support

Tile {
    DBus.Properties {
        id: profiles
        busType: DBus.BusType.System
        service: "net.hadess.PowerProfiles"
        path: "/net/hadess/PowerProfiles"
        iface: "net.hadess.PowerProfiles"
    }

    // writing into the properties map does not reach the service, so set the profile with a real D-Bus call
    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => disconnectSource(source)
    }

    readonly property string active: profiles.properties?.ActiveProfile ?? ""

    available: active !== ""
    checked: active === "power-saver"
    text: available ? i18n("Energy saver") : i18n("Energy saver unavailable")
    iconName: "battery-profile-powersave-symbolic"
    onToggled: exec.connectSource("dbus-send --system --print-reply --dest=net.hadess.PowerProfiles /net/hadess/PowerProfiles org.freedesktop.DBus.Properties.Set string:net.hadess.PowerProfiles string:ActiveProfile variant:string:" + (checked ? "balanced" : "power-saver"))
}
