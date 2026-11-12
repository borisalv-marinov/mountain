// Panel icon for the default output volume (plasma-pa, as in plasma-pa applet/main.qml Plasmoid.icon).
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.volume

Kirigami.Icon {
    readonly property var sink: PreferredDevice.sink
    readonly property bool real: sink && sink.name !== "auto_null"
    readonly property int percent: real ? Math.round(sink.volume / PulseAudio.NormalVolume * 100) : 0

    source: AudioIcon.forVolume(percent, real ? sink.muted : true, "")
    Accessible.name: !real ? i18n("No audio output") : sink.muted ? i18n("Audio muted") : i18n("Volume at %1%", percent)
}
