// Screen brightness on powerdevil's org.kde.ScreenBrightness (daemon/dbus/org.kde.ScreenBrightness*.xml);
// shown disabled with "Not available on this display" when nothing is controllable (most VMs, monitors without DDC/CI).
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

    readonly property bool available: displayName !== "" && maximum > 0
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
        id: slider
        Layout.fillWidth: true
        enabled: row.available
        opacity: enabled ? 1 : 0.35
        from: 0
        to: row.maximum
        stepSize: Math.max(1, Math.round(row.maximum / 100))
        value: Number(display.properties?.Brightness ?? 0)
        Accessible.name: i18n("Brightness")
        Accessible.description: row.available ? "" : unavailable.text
        onMoved: DBus.SessionBus.asyncCall({
            service: "org.kde.ScreenBrightness",
            path: display.path,
            iface: "org.kde.ScreenBrightness.Display",
            member: "SetBrightness",
            arguments: [Math.round(value), 0],
            signature: "(iu)",
        })
    }
    PC3.Label {
        id: unavailable
        visible: !row.available
        text: i18n("Not available on this display")
        color: "#C4C8CF" // 9.8:1 on the slider card
        font: Kirigami.Theme.smallFont
    }
    // keeps the slider aligned with the volume slider, which has two buttons on the right
    Item { visible: row.available; Layout.preferredWidth: 2 * 32 + parent.spacing }
}
