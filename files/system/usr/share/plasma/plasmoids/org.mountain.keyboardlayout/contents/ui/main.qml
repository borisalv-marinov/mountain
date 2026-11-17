/*
    Mountain: the taskbar's language button (ENG / БГ) works like Windows 11: a click opens a list of your languages
    (the current one marked) with "More keyboard settings"; Plasma's own button switched to the next layout on a click.
    Win+Space and Alt+Shift still switch straight away; the wheel still cycles. Mountain's own tray applet in place of Plasma's (whose QML is compiled into its plugin, so a replaced file is ignored),
    same model (org.kde.plasma.workspace.keyboardlayout) and same config; tests/check-image.sh checks the imports exist.
    Based on Plasma 6.5 applets/keyboardlayout (Andrey Butirsky). SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.workspace.keyboardlayout as KeyboardLayouts
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    KeyboardLayouts.KeyboardLayout { id: kbd }
    readonly property var current: kbd.layoutsList.length ? kbd.layoutsList[kbd.layout] : ({ shortName: "", displayName: "", longName: "" })
    readonly property bool inEmbeddedContainment: Plasmoid.containment.containmentType === PlasmaCore.Containment.CustomEmbedded

    Plasmoid.status: kbd.layoutsList.length > 1 ? PlasmaCore.Types.ActiveStatus
                   : inEmbeddedContainment ? PlasmaCore.Types.HiddenStatus : PlasmaCore.Types.PassiveStatus
    toolTipMainText: "Input language"
    toolTipSubText: current.longName + "\nWin+Space to switch"
    preferredRepresentation: compactRepresentation

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: source => disconnectSource(source)
    }

    compactRepresentation: MouseArea {
        hoverEnabled: true
        // the tray forwards every press/click to this MouseArea as well, so a plain toggle would open and close at once
        property bool wasExpanded: false
        onPressed: wasExpanded = root.expanded
        onClicked: root.expanded = !wasExpanded
        Accessible.onPressAction: root.expanded = !root.expanded
        property int wheelDelta: 0
        onWheel: wheel => {
            wheelDelta += (wheel.inverted ? -1 : 1) * (wheel.angleDelta.y ? wheel.angleDelta.y : wheel.angleDelta.x);
            while (wheelDelta >= 120) { wheelDelta -= 120; kbd.switchToPreviousLayout(); }
            while (wheelDelta <= -120) { wheelDelta += 120; kbd.switchToNextLayout(); }
        }
        PlasmaComponents3.Label {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            font.pointSize: height || Kirigami.Theme.defaultFont.pointSize
            fontSizeMode: Text.Fit
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.current.displayName || root.current.shortName
            textFormat: Text.PlainText
        }
    }

    // the Windows 11 language flyout: one row per language, the current one marked
    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 16
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredHeight: column.implicitHeight + Kirigami.Units.largeSpacing * 2
        collapseMarginsHint: true

        ColumnLayout {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Kirigami.Units.smallSpacing }
            spacing: 2

            Repeater {
                model: kbd.layoutsList
                delegate: PlasmaComponents3.ItemDelegate {
                    id: row
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    highlighted: index === kbd.layout
                    Accessible.name: modelData.longName
                    contentItem: RowLayout {
                        spacing: Kirigami.Units.largeSpacing
                        Rectangle { // the accent bar on the current language, like Windows
                            Layout.preferredWidth: 3
                            Layout.preferredHeight: Kirigami.Units.gridUnit
                            radius: 1.5
                            color: Kirigami.Theme.highlightColor
                            opacity: row.highlighted ? 1 : 0
                        }
                        PlasmaComponents3.Label {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                            text: row.modelData.displayName || row.modelData.shortName
                            font.bold: true
                            textFormat: Text.PlainText
                        }
                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            text: row.modelData.longName
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                    }
                    onClicked: {
                        kbd.layout = index;
                        root.expanded = false;
                    }
                }
            }
            Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: 4; Layout.bottomMargin: 4 }
            PlasmaComponents3.ItemDelegate {
                Layout.fillWidth: true
                text: "More keyboard settings"
                onClicked: {
                    exec.connectSource("/usr/libexec/mountain-settings-open typing >/dev/null 2>&1 &");
                    root.expanded = false;
                }
            }
        }
    }
}
