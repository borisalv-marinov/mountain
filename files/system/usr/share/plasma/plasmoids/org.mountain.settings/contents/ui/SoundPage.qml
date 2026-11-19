import QtQuick
import QtQuick.Layouts
import org.kde.plasma.private.volume

// Sound: Output and Input cards on plasma-pa (the same module as the quick-settings volume row).
ColumnLayout {
    spacing: 10

    SinkModel { id: sinks }
    SourceModel { id: sources }

    PageTitle { title: i18n("Sound") }
    DeviceCard { Layout.fillWidth: true; title: i18n("Output"); current: PreferredDevice.sink; devices: sinks }
    DeviceCard { Layout.fillWidth: true; title: i18n("Input"); input: true; current: PreferredDevice.source; devices: sources }
}
