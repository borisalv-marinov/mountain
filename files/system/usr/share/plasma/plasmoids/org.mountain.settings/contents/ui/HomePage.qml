import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Home: device card, Recommended settings, Bluetooth devices, Personalize your device.
ColumnLayout {
    id: home
    spacing: 12

    readonly property var tiles: [
        { name: "Mountain Silk", url: "file:///usr/share/wallpapers/mountain-silk/contents/images/1920x1080.png" },
        { name: "Mountain Silk dark", url: "file:///usr/share/wallpapers/mountain-silk-dark/contents/images/1920x1080.png" },
        { name: "Mountain Peaks", url: "file:///usr/share/wallpapers/mountain-peaks/contents/images_dark/1920x1080.png" }
    ]

    GText {
        Layout.topMargin: 6
        text: "Home"
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2
        font.weight: Font.DemiBold
    }

    // Device card
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        spacing: 16

        Rectangle {
            Layout.preferredWidth: 128
            Layout.preferredHeight: 76
            radius: 8
            color: app.glassBottom
            border.width: 2
            border.color: Qt.rgba(1, 1, 1, 0.22)
            Image {
                anchors.fill: parent
                anchors.margins: 3
                source: app.wallpaper
                sourceSize.width: 256
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                Accessible.ignored: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            GText {
                Layout.fillWidth: true
                text: kuser.host
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                font.weight: Font.DemiBold
            }
            GText {
                Layout.fillWidth: true
                visible: text !== ""
                text: app.modelName
                dim: true
            }
            QQC2.AbstractButton {
                id: renameLink
                text: "Rename"
                hoverEnabled: true
                activeFocusOnTab: true
                Accessible.name: "Rename this PC"
                onClicked: app.openKcm("kcm_about-distro")
                Keys.onReturnPressed: clicked()
                contentItem: GText {
                    text: renameLink.text
                    color: app.accent
                    font.underline: renameLink.hovered || renameLink.visualFocus
                }
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: home.width > 700 ? 2 : 1
        columnSpacing: 12
        rowSpacing: 12

        // Left column
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: 12

            GlassCard {
                Layout.fillWidth: true
                padding: 6
                CardHeader { title: "Recommended settings"; subtitle: "Recent and commonly used settings" }
                SettingRow { text: "Sound"; iconName: "preferences-desktop-sound"; onClicked: app.openKcm("kcm_pulseaudio") }
                SettingRow { text: "Power & battery"; iconName: "battery"; divider: true; onClicked: app.openKcm("kcm_powerdevilprofilesconfig") }
                SettingRow { text: "Display"; iconName: "preferences-desktop-display"; divider: true; onClicked: app.openKcm("kcm_kscreen") }
            }

            GlassCard {
                Layout.fillWidth: true
                padding: 6
                CardHeader { title: "Personalize your device" }

                Flow {
                    Layout.fillWidth: true
                    Layout.leftMargin: 18
                    Layout.rightMargin: 18
                    Layout.bottomMargin: 14
                    spacing: 8
                    Repeater {
                        model: home.tiles
                        delegate: QQC2.AbstractButton {
                            id: tile
                            required property var modelData
                            width: 120
                            height: 76
                            padding: 3
                            hoverEnabled: true
                            activeFocusOnTab: true
                            text: modelData.name
                            Accessible.name: "Set background " + modelData.name
                            onClicked: app.setWallpaper(modelData.url)
                            Keys.onReturnPressed: clicked()
                            background: Rectangle {
                                radius: 6
                                color: app.glassBottom
                                border.width: app.wallpaper === tile.modelData.url || tile.visualFocus ? 2 : 1
                                border.color: app.wallpaper === tile.modelData.url || tile.visualFocus ? app.accent
                                                : (tile.hovered ? Qt.rgba(1, 1, 1, 0.4) : app.rim)
                            }
                            contentItem: Image {
                                source: tile.modelData.url
                                sourceSize.width: 240
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }
                    }
                }

                // Color mode: two calm segments instead of a dropdown.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 14
                    Layout.preferredHeight: 52
                    spacing: 14
                    Kirigami.Icon {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        source: "preferences-desktop-color"
                    }
                    GText { Layout.fillWidth: true; text: "Color mode" }
                    GlassButton {
                        text: "Dark"
                        implicitWidth: 80
                        highlighted: app.colorMode === "Dark"
                        Accessible.name: "Color mode Dark"
                        onClicked: app.setColorMode("Dark")
                    }
                    GlassButton {
                        text: "Light"
                        implicitWidth: 80
                        highlighted: app.colorMode === "Light"
                        Accessible.name: "Color mode Light"
                        onClicked: app.setColorMode("Light")
                    }
                }

                SettingRow {
                    text: "Browse more backgrounds, colors, and themes"
                    divider: true
                    onClicked: app.page = "background"
                }
            }
        }

        // Right column
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: 12

            // Optional backend: a missing org.kde.bluezqt only hides this card.
            Loader {
                id: btLoader
                Layout.fillWidth: true
                Layout.preferredHeight: item ? item.implicitHeight : 0
                visible: status === Loader.Ready
                source: "BluetoothCard.qml"
            }

            GlassCard {
                Layout.fillWidth: true
                padding: 6
                CardHeader { title: "Updates"; subtitle: "Updates are manual. Run them when you choose." }
                SettingRow {
                    text: "Check for updates"
                    iconName: "system-software-update"
                    onClicked: app.run("kstart --application io.github.rfrench3.bazzite-updater")
                }
            }
        }
    }
}
