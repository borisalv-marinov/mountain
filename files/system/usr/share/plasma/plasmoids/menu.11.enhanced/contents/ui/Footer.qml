import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import QtCore

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras

import org.kde.plasma.private.kicker 0.1 as Kicker
import org.kde.coreaddons 1.0 as KCoreAddons
import org.kde.plasma.private.shell

import org.kde.kwindowsystem
import org.kde.kquickcontrolsaddons

import org.kde.plasma.components as PlasmaComponents3


import org.kde.kirigami as Kirigami
import org.kde.plasma.private.sessions
import org.kde.plasma.plasma5support as P5Support

RowLayout{

    spacing: Kirigami.Units.largeSpacing

    KCoreAddons.KUser {   id: kuser  }
    Logic {   id: logic }

    SessionManagement {
        id: sessionManager
    }
    // Mountain: Windows 11 account menu (click your name) and power menu; "Restart into Windows" only with a Windows boot entry
    property bool windowsBoot: false
    P5Support.DataSource {
        id: winCheck
        engine: "executable"
        connectedSources: ["/usr/libexec/mountain-windows-boot check"]
        onNewData: (source, data) => { windowsBoot = data["exit code"] === 0; disconnectSource(source); }
    }
    PlasmaComponents3.Menu {
        id: accountMenu
        PlasmaComponents3.MenuItem { text: i18n("Change account settings"); icon.name: "user-identity"; onClicked: logic.runCommand("systemsettings kcm_users") }
        PlasmaComponents3.MenuItem { text: i18n("Lock"); icon.name: "system-lock-screen"; visible: sessionManager.canLock; onClicked: sessionManager.lock() }
        PlasmaComponents3.MenuItem { text: i18n("Sign out"); icon.name: "system-log-out"; onClicked: sessionManager.requestLogout() }
    }
    PlasmaComponents3.Menu {
        id: powerMenu
        PlasmaComponents3.MenuItem { text: i18n("Sleep"); icon.name: "system-suspend"; onClicked: sessionManager.suspend() }
        PlasmaComponents3.MenuItem { text: i18n("Shut down"); icon.name: "system-shutdown"; onClicked: sessionManager.requestShutdown() }
        PlasmaComponents3.MenuItem { text: i18n("Restart"); icon.name: "system-reboot"; onClicked: sessionManager.requestReboot() }
        PlasmaComponents3.MenuItem {
            text: i18n("Restart into Windows")
            icon.name: "system-reboot"
            visible: windowsBoot
            height: visible ? implicitHeight : 0
            onClicked: logic.runCommand("/usr/libexec/mountain-windows-boot go")
        }
    }

    RowLayout{
        Image {
            id: iconUser
            source: {
                var faceUrl = kuser.faceIconUrl.toString()
                if (faceUrl !== "") {
                    return faceUrl
                }
                return "file://usr/share/icons/breeze/apps/48/kuser.svg"
            }
            cache: false
            visible: source !== ""
            sourceSize.height: 24
            sourceSize.width: 24
            fillMode: Image.PreserveAspectFit
            Layout.alignment: Qt.AlignVCenter
            layer.enabled: true
            
            MouseArea {
                cursorShape: Qt.PointingHandCursor
                anchors.fill: parent
                onClicked: accountMenu.popup()
            }
        }

        PlasmaExtras.Heading {
            wrapMode: Text.NoWrap
            color: Kirigami.Theme.textColor
            level: 3
            font.bold: true
            text: qsTr(kuser.fullName)
            
            MouseArea {
                cursorShape: Qt.PointingHandCursor
                anchors.fill: parent
                onClicked: accountMenu.popup()
            }
        }   
    }


    PlasmaComponents3.ToolButton {
        icon.width: 24
        icon.height: 24
        icon.name:  "user-home"
        
        Layout.leftMargin: 10
        PlasmaComponents3.ToolTip.delay: 1000
        PlasmaComponents3.ToolTip.timeout: 1000
        PlasmaComponents3.ToolTip.visible: hovered
        PlasmaComponents3.ToolTip.text: i18n("User Home")
        
        onClicked: logic.openUrl(StandardPaths.writableLocation(StandardPaths.HomeLocation).toString())
    }

    PlasmaComponents3.ToolButton {
        icon.width: 24
        icon.height: 24
        icon.name:  "configure"
        Layout.leftMargin: 10
        PlasmaComponents3.ToolTip.delay: 1000
        PlasmaComponents3.ToolTip.timeout: 1000
        PlasmaComponents3.ToolTip.visible: hovered
        PlasmaComponents3.ToolTip.text: i18n("System Preferences")
        
        onClicked: logic.runCommand("plasmawindowed org.mountain.settings")
    }

    Item{
        Layout.fillWidth: true
    }

    PlasmaComponents3.ToolButton {
        icon.width: 24
        icon.height: 24
        icon.name: "system-shutdown"
        Layout.rightMargin: 10
        Accessible.name: i18n("Power")
        PlasmaComponents3.ToolTip.delay: 1000
        PlasmaComponents3.ToolTip.timeout: 1000
        PlasmaComponents3.ToolTip.visible: hovered
        PlasmaComponents3.ToolTip.text: i18n("Power")
        onClicked: powerMenu.popup()
    }
}
