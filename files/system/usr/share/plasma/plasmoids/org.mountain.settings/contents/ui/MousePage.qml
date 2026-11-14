import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Mouse & touchpad: KWin's input-device D-Bus API changes the device now; kcminputrc (Libinput/vendor/product/name) keeps it
// for the next sign-in, the same file and keys Plasma's own mouse page writes. Settings apply to every device of that kind.
ColumnLayout {
    id: mp
    spacing: 10
    property var mouse: null    // { speed, natural, left } or null when no mouse is found
    property var pad: null      // { speed, natural, left, tap }

    // run `body` once per pointer device of this kind; q PROP [VALUE] reads/sets an org.kde.KWin.InputDevice property
    function each(touchpad, body) {
        return "for d in $(qdbus6 org.kde.KWin /org/kde/KWin/InputDevice org.kde.KWin.InputDeviceManager.devicesSysNames); do "
            + "p=/org/kde/KWin/InputDevice/$d; q() { qdbus6 org.kde.KWin $p org.kde.KWin.InputDevice.$1 $2; }; "
            + "[ \"$(q pointer)\" = true ] && [ \"$(q touchpad)\" = " + touchpad + " ] || continue; " + body + "; done";
    }
    function read(touchpad, done) {
        app.sh(each(touchpad, "echo $(q pointerAcceleration); echo $(q naturalScroll); echo $(q leftHanded); echo $(q tapToClick); break") + " # " + Date.now(), out => {
            const l = out.split("\n");
            done(l.length < 3 ? null : { speed: parseFloat(l[0]) || 0, natural: l[1] === "true", left: l[2] === "true", tap: l[3] === "true" });
        });
    }
    function load() {
        read(false, r => mouse = r);
        read(true, r => pad = r);
    }
    // prop = KWin property, key = kcminputrc key; value is one of our own literals
    function set(touchpad, prop, key, value, type) {
        app.sh(each(touchpad, "q " + prop + " " + value + "; kwriteconfig6 --file kcminputrc --group Libinput --group $(q vendor) --group $(q product) --group \"$(q name)\" --key "
            + key + " --type " + type + " " + value) + " # " + Date.now(), load);
    }
    Component.onCompleted: load()

    PageTitle { title: "Mouse & touchpad" }

    GText { visible: !mp.mouse && !mp.pad; text: "No mouse or touchpad found."; dim: true }

    Repeater {
        model: [{ pad: false, title: "Mouse" }, { pad: true, title: "Touchpad" }]
        delegate: GlassCard {
            id: card
            required property var modelData
            readonly property var s: modelData.pad ? mp.pad : mp.mouse
            visible: s !== null
            function flip(prop, key, cur) { mp.set(modelData.pad, prop, key, cur ? "false" : "true", "bool"); }
            Layout.fillWidth: true
            padding: 6
            CardHeader { title: card.modelData.title; subtitle: "Changes apply to every " + card.modelData.title.toLowerCase() + " on this PC" }
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 18
                Layout.preferredHeight: 48
                spacing: 14
                GText { text: "Pointer speed" }
                QQC2.Slider {
                    id: speed
                    Layout.fillWidth: true
                    from: -1
                    to: 1
                    stepSize: 0.1
                    Accessible.name: card.modelData.title + " pointer speed"
                    Binding on value { when: !speed.pressed; value: card.s ? card.s.speed : 0 }
                    onPressedChanged: if (!pressed) mp.set(card.modelData.pad, "pointerAcceleration", "PointerAcceleration", value.toFixed(1), "double")
                }
            }
            SettingRow {
                text: "Natural scrolling"
                description: "Content moves with your fingers"
                chevron: false
                onClicked: card.flip("naturalScroll", "NaturalScroll", card.s.natural)
                trailing: PillSwitch { text: "Natural scrolling"; checked: card.s ? card.s.natural : false; onClicked: card.flip("naturalScroll", "NaturalScroll", card.s.natural) }
            }
            SettingRow {
                text: "Swap left and right buttons"
                chevron: false
                divider: true
                onClicked: card.flip("leftHanded", "LeftHanded", card.s.left)
                trailing: PillSwitch { text: "Swap left and right buttons"; checked: card.s ? card.s.left : false; onClicked: card.flip("leftHanded", "LeftHanded", card.s.left) }
            }
            SettingRow {
                visible: card.modelData.pad
                text: "Tap to click"
                chevron: false
                divider: true
                onClicked: card.flip("tapToClick", "TapToClick", card.s.tap)
                trailing: PillSwitch { text: "Tap to click"; checked: card.s ? card.s.tap : false; onClicked: card.flip("tapToClick", "TapToClick", card.s.tap) }
            }
        }
    }
}
