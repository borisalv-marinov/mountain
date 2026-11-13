// Volume of the default output on plasma-pa (calls as in plasma-pa applet/ListItemBase.qml), with mute and an output picker.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.private.volume

ColumnLayout {
    id: volume

    readonly property var sink: PreferredDevice.sink
    readonly property bool real: sink && sink.name !== "auto_null"
    property bool picking: false

    spacing: Kirigami.Units.smallSpacing

    SinkModel { id: sinks }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing
        enabled: volume.real

        PC3.ToolButton {
            icon.name: AudioIcon.forVolume(volume.real ? Math.round(volume.sink.volume / PulseAudio.NormalVolume * 100) : 0,
                                           volume.real ? volume.sink.muted : true, "")
            display: PC3.AbstractButton.IconOnly
            text: volume.real && volume.sink.muted ? i18n("Unmute") : i18n("Mute")
            Accessible.name: text
            onClicked: volume.sink.muted = !volume.sink.muted
        }
        PC3.Slider {
            Layout.fillWidth: true
            from: PulseAudio.MinimalVolume
            to: PulseAudio.NormalVolume
            stepSize: PulseAudio.NormalVolume / 100
            value: volume.real ? volume.sink.volume : 0
            opacity: volume.real && volume.sink.muted ? 0.5 : 1
            Accessible.name: i18n("Volume")
            onMoved: volume.sink.volume = Math.round(value)
        }
        PC3.ToolButton {
            icon.name: "go-next-symbolic" // Windows' ">" output picker beside the volume slider

            display: PC3.AbstractButton.IconOnly
            text: i18n("Choose audio output")
            Accessible.name: text
            checkable: true
            checked: volume.picking
            onToggled: volume.picking = checked
        }
    }

    Repeater {
        model: volume.picking ? sinks : null
        delegate: PC3.ItemDelegate {
            required property var model
            Layout.fillWidth: true
            visible: model.PulseObject.name !== "auto_null"
            text: model.PulseObject.description || model.PulseObject.name
            icon.name: model.PulseObject.default ? "checkmark-symbolic" : "audio-card-symbolic"
            Accessible.name: text
            onClicked: { model.PulseObject.default = true; volume.picking = false; }
        }
    }
}
