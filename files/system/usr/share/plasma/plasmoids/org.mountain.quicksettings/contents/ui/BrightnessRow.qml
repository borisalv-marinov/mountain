// Screen brightness on powerdevil's org.kde.ScreenBrightness (daemon/dbus/org.kde.ScreenBrightness*.xml);
// hidden when no display is controllable (e.g. most VMs and desktop monitors without DDC).
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.workspace.dbus as DBus

RowLayout {
    id: row

    DBus.Properties {
        id: screens
        busType: DBus.BusType.Session
        service: "org.kde.ScreenBrightness"
        path: "/org/kde/ScreenBrightness"
        iface: "org.kde.ScreenBrightness"
    }
    readonly property string displayName: (screens.properties?.DisplaysDBusNames ?? [])[0] ?? ""
    DBus.Properties {
        id: display
        busType: DBus.BusType.Session
        service: "org.kde.ScreenBrightness"
        path: row.displayName ? "/org/kde/ScreenBrightness/" + row.displayName : ""
        iface: "org.kde.ScreenBrightness.Display"
    }
    readonly property int maximum: Number(display.properties?.MaxBrightness ?? 0)

    visible: displayName !== "" && maximum > 0
    spacing: Kirigami.Units.smallSpacing

    Kirigami.Icon {
        Layout.preferredWidth: Kirigami.Units.iconSizes.small
        Layout.preferredHeight: Kirigami.Units.iconSizes.small
        Layout.margins: 8
        source: "brightness-high-symbolic"
        isMask: true
        color: "#F2F3F5"
        Accessible.ignored: true
    }
    PC3.Slider {
        Layout.fillWidth: true
        from: 0
        to: row.maximum
        stepSize: Math.max(1, Math.round(row.maximum / 100))
        value: Number(display.properties?.Brightness ?? 0)
        Accessible.name: i18n("Brightness")
        onMoved: DBus.SessionBus.asyncCall({
            service: "org.kde.ScreenBrightness",
            path: display.path,
            iface: "org.kde.ScreenBrightness.Display",
            member: "SetBrightness",
            arguments: [Math.round(value), 0],
            signature: "(iu)",
        })
    }
    // keeps the slider aligned with the volume slider, which has two buttons on the right
    Item { Layout.preferredWidth: 2 * 32 + parent.spacing }
}
