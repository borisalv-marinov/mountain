import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// App permissions: each installed Flatpak app with Files, Camera and Microphone switches (like Windows 11).
// The state is read back from Flatpak after every change (mountain-app-permissions), so a switch never shows more than is true.
ColumnLayout {
    id: ap
    spacing: 10
    property var apps: [] // [{ id, name, files, camera, mic }]
    readonly property string helper: "/usr/libexec/mountain-app-permissions"
    readonly property var kinds: [
        { k: "files", t: i18n("Files"), d: i18n("Let this app see your home folder, Documents and Downloads") },
        { k: "camera", t: i18n("Camera"), d: i18n("Let this app use your camera") },
        { k: "mic", t: i18n("Microphone"), d: i18n("Let this app use your microphone") }
    ]

    function load() {
        app.sh(helper + " list # " + Date.now(), out => {
            apps = out === "" ? [] : out.split("\n").map(r => { const f = r.split("\t"); return { id: f[0], name: f[1], files: f[2] === "on", camera: f[3] === "on", mic: f[4] === "on" }; });
        });
    }
    function flip(a, kind) { // the id is an app id (letters, digits, dots): the helper refuses anything else
        app.sh(helper + " set '" + a.id.split("'").join("") + "' " + kind + " " + (a[kind] ? "off" : "on") + " # " + Date.now(), load);
    }
    Component.onCompleted: load()

    PageTitle { title: i18n("App permissions") }
    GText { Layout.fillWidth: true; wrapMode: Text.WordWrap; dim: true; text: i18n("Choose what each app may use. A change reaches an app the next time it starts.") }

    Repeater {
        model: ap.apps
        delegate: GlassCard {
            id: card
            required property var modelData
            Layout.fillWidth: true
            padding: 6
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 18
                Layout.topMargin: 14
                Layout.bottomMargin: 6
                spacing: 12
                Kirigami.Icon { source: card.modelData.id; fallback: "application-x-executable"; Layout.preferredWidth: 32; Layout.preferredHeight: 32 }
                GText { Layout.fillWidth: true; text: card.modelData.name; font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.25; font.weight: Font.DemiBold }
            }
            Repeater {
                model: ap.kinds
                delegate: SettingRow {
                    required property var modelData
                    required property int index
                    readonly property bool isOn: card.modelData[modelData.k]
                    text: modelData.t
                    description: modelData.d
                    chevron: false
                    divider: index > 0
                    onClicked: ap.flip(card.modelData, modelData.k)
                    trailing: [
                        GText { text: isOn ? i18n("On") : i18n("Off") },
                        PillSwitch { text: card.modelData.name + ": " + modelData.t; checked: isOn; onClicked: ap.flip(card.modelData, modelData.k) }
                    ]
                }
            }
        }
    }
    GText { visible: ap.apps.length === 0; text: i18n("No apps from the app store are installed."); dim: true }
}
