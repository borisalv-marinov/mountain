/*
    Mountain: the taskbar's language button (ENG / БГ) works like Windows 11: a click opens a list of your languages
    (the current one marked) with "More keyboard settings"; Plasma's own button switched to the next layout on a click.
    Win+Space and Alt+Shift still switch straight away; the wheel still cycles. Mountain's own tray applet in place of Plasma's,
    same model (org.kde.plasma.workspace.keyboardlayout) and same config; tests/check-image.sh checks the imports exist.
    Built like Plasma's (the button is the full representation, drawn in the tray); the list is this applet's own pop-up
    window, because the tray's expand-into-its-popup path never showed it (two VM runs).
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
    toolTipMainText: i18n("Input language")
    toolTipSubText: current.longName + "\n" + i18n("Win+Space to switch")
    preferredRepresentation: fullRepresentation
    Plasmoid.onActivated: list.visible = !list.visible

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: source => disconnectSource(source)
    }

    fullRepresentation: MouseArea {
        id: button
        hoverEnabled: true
        // the tray forwards every press/click to this MouseArea as well; a click on the open list's button closes it
        // (the press already hid it by taking the focus away), so remember what was open at the press
        property bool wasOpen: false
        onPressed: wasOpen = list.visible
        onClicked: list.visible = !wasOpen
        Accessible.role: Accessible.Button
        Accessible.name: root.current.longName
        Accessible.onPressAction: list.visible = !list.visible
        property int wheelDelta: 0
        onWheel: wheel => {
            wheelDelta += (wheel.inverted ? -1 : 1) * (wheel.angleDelta.y ? wheel.angleDelta.y : wheel.angleDelta.x);
            while (wheelDelta >= 120) { wheelDelta -= 120; kbd.switchToPreviousLayout(); }
            while (wheelDelta <= -120) { wheelDelta += 120; kbd.switchToNextLayout(); }
        }
        Component.onCompleted: list.visualParent = button
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
    PlasmaCore.Dialog {
        id: list
        // in the tray the applet's own location is not a screen edge, so Plasma put the list at the screen's bottom,
        // behind the taskbar; an edge puts it above (or beside) the button
        location: Plasmoid.location >= PlasmaCore.Types.TopEdge && Plasmoid.location <= PlasmaCore.Types.RightEdge ? Plasmoid.location : PlasmaCore.Types.BottomEdge
        type: PlasmaCore.Dialog.PopupMenu
        hideOnWindowDeactivate: true
        flags: Qt.WindowStaysOnTopHint
        onVisibleChanged: if (visible) column.forceActiveFocus()

        mainItem: ColumnLayout {
            id: column
            // a size known before the list first shows: a layout only measures itself once its window is on screen, so
            // Plasma placed the list while it was one row tall and it grew down behind the taskbar (VM runs 17 Nov)
            readonly property real rowHeight: Kirigami.Units.gridUnit * 2
            width: Kirigami.Units.gridUnit * 18
            height: (kbd.layoutsList.length + 1) * rowHeight + 9
            spacing: 0
            Keys.onEscapePressed: list.visible = false

            Repeater {
                model: kbd.layoutsList
                delegate: PlasmaComponents3.ItemDelegate {
                    id: row
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: column.rowHeight
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
                        list.visible = false;
                    }
                }
            }
            Kirigami.Separator { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: 4; Layout.bottomMargin: 4 }
            PlasmaComponents3.ItemDelegate {
                Layout.fillWidth: true
                Layout.preferredHeight: column.rowHeight
                text: i18n("More keyboard settings")
                onClicked: {
                    exec.connectSource("/usr/libexec/mountain-settings-open typing >/dev/null 2>&1 &");
                    list.visible = false;
                }
            }
        }
    }
}
