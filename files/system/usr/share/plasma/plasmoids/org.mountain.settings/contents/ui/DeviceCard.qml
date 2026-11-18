import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.volume

// Sound: one card for the output or the input side. Volume and mute as in the quick-settings VolumeRow
// (plasma-pa calls), plus the device list; a click on a device makes it the default.
GlassCard {
    id: card
    property string title: ""
    property bool input: false
    property var current: null // PreferredDevice.sink or .source
    property alias devices: list.model
    readonly property bool real: current !== null && current !== undefined && current.name !== "auto_null"
    readonly property int percent: real ? Math.round(current.volume / PulseAudio.NormalVolume * 100) : 0
    padding: 6

    CardHeader { title: card.title; subtitle: card.real ? (card.current.description || card.current.name) : card.input ? i18n("No microphone found") : i18n("No speakers found") }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 14
        Layout.rightMargin: 18
        Layout.bottomMargin: 8
        spacing: 10
        enabled: card.real

        QQC2.ToolButton {
            icon.name: card.input ? (!card.real || card.current.muted ? "microphone-sensitivity-muted" : "microphone-sensitivity-high")
                                  : AudioIcon.forVolume(card.percent, card.real ? card.current.muted : true, "")
            icon.color: app.textColor
            display: QQC2.AbstractButton.IconOnly
            text: card.real && card.current.muted ? i18n("Unmute") : i18n("Mute")
            Accessible.name: text
            onClicked: card.current.muted = !card.current.muted
        }
        QQC2.Slider {
            id: slider
            Layout.fillWidth: true
            from: PulseAudio.MinimalVolume
            to: PulseAudio.NormalVolume
            stepSize: PulseAudio.NormalVolume / 100
            opacity: card.real && card.current.muted ? 0.5 : 1
            Accessible.name: i18n("%1 volume", card.title)
            // follow the device only while not dragging: its echo of our own change arrives late and made the knob jump back
            Binding on value { when: !slider.pressed; value: card.real ? card.current.volume : 0 }
            onMoved: {
                card.current.volume = Math.round(value);
                if (value > 0 && card.current.muted) {
                    card.current.muted = false; // dragging up un-mutes, as in the Plasma applet
                }
            }
        }
        GText {
            Layout.preferredWidth: 44
            horizontalAlignment: Text.AlignRight
            text: card.percent + "%"
            Accessible.name: i18n("%1 percent", card.percent)
        }
    }

    Repeater {
        id: list
        delegate: SettingRow {
            id: dev
            required property var model
            readonly property bool isDefault: model.PulseObject.default
            visible: model.PulseObject.name.indexOf(".monitor") < 0 && model.PulseObject.name !== "auto_null"
            text: model.PulseObject.description || model.PulseObject.name
            iconName: card.input ? "audio-input-microphone" : "audio-card"
            chevron: false
            Accessible.checked: isDefault
            onClicked: model.PulseObject.default = true
            trailing: Kirigami.Icon {
                visible: dev.isDefault
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                source: "checkmark"
                color: app.accent
                isMask: true
            }
        }
    }
}
