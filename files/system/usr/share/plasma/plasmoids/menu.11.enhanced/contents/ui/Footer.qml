import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

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
import org.kde.kirigamiaddons.components as KirigamiComponents // Avatar left Kirigami in KF6
import org.kde.plasma.private.sessions
import org.kde.plasma.plasma5support as P5Support

RowLayout{
    id: footerRow
    // Mountain: Windows 11 footer, the account (avatar and name) on the left and power on the right
    readonly property string userName: kuser.fullName || kuser.loginName
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
            onClicked: logic.runCommand("/usr/libexec/mountain-windows-boot go --no-restart && dbus-send --session --type=method_call --dest=org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptReboot")
        }
    }

    PlasmaComponents3.ToolButton {
        id: accountButton
        Accessible.name: footerRow.userName
        Accessible.description: i18n("Account settings, lock and sign out")
        onClicked: accountMenu.popup(accountButton, 0, -accountMenu.implicitHeight)
        contentItem: RowLayout {
            spacing: Kirigami.Units.largeSpacing
            KirigamiComponents.Avatar { // round picture, initials when there is none
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                source: kuser.faceIconUrl
                name: footerRow.userName
            }
            PlasmaComponents3.Label {
                text: footerRow.userName
                color: Kirigami.Theme.textColor
                elide: Text.ElideRight
                Layout.maximumWidth: Kirigami.Units.gridUnit * 14
            }
        }
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
