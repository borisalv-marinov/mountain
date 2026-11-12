// Battery icon (+ percentage) from UPower's DisplayDevice; invisible when there is no battery.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.workspace.dbus as DBus

RowLayout {
    id: battery

    property bool showText: true
    property int iconSize: Kirigami.Units.iconSizes.small
    readonly property bool present: Boolean(upower.properties?.IsPresent)
    readonly property int percent: Math.round(Number(upower.properties?.Percentage ?? 0))

    DBus.Properties {
        id: upower
        busType: DBus.BusType.System
        service: "org.freedesktop.UPower"
        path: "/org/freedesktop/UPower/devices/DisplayDevice"
        iface: "org.freedesktop.UPower.Device"
    }

    visible: present
    spacing: Kirigami.Units.smallSpacing
    Accessible.role: Accessible.StaticText
    Accessible.name: i18n("Battery at %1%", percent)

    Kirigami.Icon {
        Layout.preferredWidth: battery.iconSize
        Layout.preferredHeight: battery.iconSize
        source: upower.properties?.IconName || "battery-100-symbolic"
        fallback: "battery-100-symbolic"
    }
    PC3.Label {
        visible: battery.showText
        text: i18nc("battery percentage", "%1%", battery.percent)
        color: "#F2F3F5"
    }
}
