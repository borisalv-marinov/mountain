import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Accessibility (Windows 11 names). Every switch and highlighted button shows what mountain-accessibility status reads back
// (Orca really running, KWin's filter really enabled), never what was last clicked.
ColumnLayout {
    id: ac
    spacing: 10
    property var st: ({})
    readonly property string helper: "/usr/libexec/mountain-accessibility "

    function load() {
        app.sh(helper + "status # " + Date.now(), out => {
            let s = {};
            for (const l of out.split("\n")) { const i = l.indexOf("="); if (i > 0) s[l.slice(0, i)] = l.slice(i + 1); }
            st = s;
        });
    }
    function set(args) { // args are this page's own literals, never user text
        app.sh(helper + args + " # " + Date.now(), () => args.startsWith("narrator") ? recheck.restart() : load());
    }
    Timer { id: recheck; interval: 1500; onTriggered: ac.load() } // Orca needs a moment to start or quit
    Component.onCompleted: load()

    component Head: RowLayout {
        id: head
        property string icon
        property string title
        property string sub
        default property alias trailing: slot.data
        Layout.fillWidth: true
        Layout.leftMargin: 14
        Layout.rightMargin: 18
        Layout.preferredHeight: 60
        spacing: 14
        Kirigami.Icon { Layout.preferredWidth: 24; Layout.preferredHeight: 24; source: head.icon + "-symbolic"; fallback: head.icon; isMask: true; color: Kirigami.Theme.textColor }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            GText { Layout.fillWidth: true; text: head.title }
            GText { Layout.fillWidth: true; dim: true; wrapMode: Text.WordWrap; text: head.sub; font.pointSize: Kirigami.Theme.smallFont.pointSize }
        }
        RowLayout { id: slot; spacing: 10 }
    }
    component Choices: Flow {
        Layout.fillWidth: true
        Layout.leftMargin: 52
        Layout.rightMargin: 18
        Layout.bottomMargin: 12
        spacing: 8
    }

    PageTitle { title: i18n("Accessibility") }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        Head {
            icon: "audio-speakers"; title: i18n("Narrator"); sub: i18n("Reads aloud what is on the screen. Win+Ctrl+Enter turns it on or off")
            GText { text: ac.st.narrator === "on" ? i18n("On") : i18n("Off") }
            PillSwitch { text: i18n("Narrator"); checked: ac.st.narrator === "on"; onClicked: ac.set("narrator " + (checked ? "off" : "on")) }
        }
    }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        Head { icon: "zoom-fit-best"; title: i18n("Magnifier"); sub: i18n("Zoom in on the screen: Win+Plus and Win+Minus, Win+Esc back to normal") }
        Choices {
            GlassButton { text: i18n("Zoom in"); onClicked: ac.set("zoom in") }
            GlassButton { text: i18n("Back to normal"); onClicked: ac.set("zoom off") }
        }
    }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        Head { icon: "color-management"; title: i18n("Color filters"); sub: i18n("Make colors easier to tell apart. Win+Ctrl+C turns the filter on or off") }
        Choices {
            Repeater {
                model: [{ v: "off", t: i18n("Off") }, { v: "deuteranopia", t: i18n("Red-green (green weak)") },
                        { v: "protanopia", t: i18n("Red-green (red weak)") }, { v: "tritanopia", t: i18n("Blue-yellow") }]
                GlassButton { required property var modelData; text: modelData.t; highlighted: ac.st.filter === modelData.v; onClicked: ac.set("filter " + modelData.v) }
            }
        }
    }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        Head { icon: "input-mouse"; title: i18n("Mouse pointer size"); sub: i18n("Make the pointer easier to see (apps opened after the change use it)") }
        Choices {
            Repeater {
                model: [{ v: "24", t: i18n("Normal") }, { v: "32", t: i18n("Large") }, { v: "48", t: i18n("Larger") }, { v: "64", t: i18n("Largest") }]
                GlassButton { required property var modelData; text: modelData.t; highlighted: ac.st.cursor === modelData.v; onClicked: ac.set("cursor " + modelData.v) }
            }
        }
    }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        Head {
            icon: "input-keyboard"; title: i18n("Sticky keys"); sub: i18n("Press Ctrl, Alt, Shift or Win one at a time for a shortcut")
            GText { text: ac.st.sticky === "on" ? i18n("On") : i18n("Off") }
            PillSwitch { text: i18n("Sticky keys"); checked: ac.st.sticky === "on"; onClicked: ac.set("sticky " + (checked ? "off" : "on")) }
        }
        Head {
            icon: "special-effects"; title: i18n("Animation effects"); sub: i18n("Windows and menus slide and fade")
            GText { text: ac.st.animations === "off" ? i18n("Off") : i18n("On") }
            PillSwitch { text: i18n("Animation effects"); checked: ac.st.animations !== "off"; onClicked: ac.set("animations " + (checked ? "off" : "on")) }
        }
    }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        SettingRow { iconName: "redshift-status-on"; text: i18n("Night light"); description: i18n("Warmer colors at night"); onClicked: app.page = "nightlight" }
        SettingRow { divider: true; iconName: "monitor"; text: i18n("Text size"); description: i18n("Make everything bigger with Display > Scale"); onClicked: app.page = "display" }
        SettingRow { divider: true; iconName: "special-effects"; text: i18n("Transparency effects"); description: i18n("Glass on the taskbar, start menu and flyouts: click to turn on or off"); onClicked: app.run("/usr/libexec/mountain-personalize glass toggle") }
    }
}
