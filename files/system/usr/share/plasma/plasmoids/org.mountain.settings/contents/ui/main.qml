/*
    Mountain Settings: Windows 11 structure, black glass look.
    Run with `plasmawindowed org.mountain.settings`. Every page opens the real KDE module.
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kcmutils as KCMUtils
import org.kde.coreaddons as KCoreAddons

PlasmoidItem {
    id: app

    // Desktop wallpaper shown on the Home device card (the integrator may change this path).
    property string wallpaper: "file:///usr/share/wallpapers/mountain-silk/contents/images/1920x1080.png"

    // Design tokens (docs/superpowers/plans/2026-11-12-mountain-v5-black-glass.md)
    readonly property color glassTop: "#1B1D22"
    readonly property color glassBottom: "#07080A"
    readonly property color pageColor: "#050607"
    readonly property color rim: Qt.rgba(1, 1, 1, 0.14)
    readonly property color rimTop: Qt.rgba(1, 1, 1, 0.38)
    readonly property color innerShadow: Qt.rgba(0, 0, 0, 0.60)
    readonly property color textColor: "#F2F3F5"
    readonly property color textDim: "#A4A9B2"
    readonly property color accent: "#5AB0FF"
    readonly property color selection: "#2A6CC4"
    readonly property color hover: Qt.rgba(1, 1, 1, 0.08)

    property string page: "home"
    property string query: ""
    property string modelName: ""
    property string colorMode: "Dark"

    readonly property string modelCmd: "cat /sys/devices/virtual/dmi/id/product_name"
    readonly property string colorCmd: "kreadconfig6 --file kdeglobals --group General --key ColorScheme"

    // Windows 11 categories and their sub-pages. kcm = System Settings module id,
    // info = Info Center module id, cmd = shell command, k = extra search keywords.
    readonly property var categories: [
        { id: "home", name: "Home", icon: "user-home", items: [] },
        { id: "system", name: "System", icon: "preferences-system", items: [
            { t: "Display", d: "Monitors, brightness, resolution, scale", i: "preferences-desktop-display", kcm: "kcm_kscreen", k: "screen monitor resolution refresh hdr" },
            { t: "Sound", d: "Volume, output and input devices", i: "preferences-desktop-sound", kcm: "kcm_pulseaudio", k: "audio speaker microphone headphones" },
            { t: "Notifications", d: "Alerts from apps and system, do not disturb", i: "preferences-desktop-notification-bell", kcm: "kcm_notifications", k: "alerts do not disturb" },
            { t: "Power & battery", d: "Sleep, screen off, battery saver", i: "battery", kcm: "kcm_powerdevilprofilesconfig", k: "power sleep suspend energy" },
            { t: "Storage", d: "Drives and partitions", i: "drive-harddisk", info: "kcm_block_devices", k: "disk drive space ssd" },
            { t: "Multitasking", d: "Virtual desktops", i: "preferences-desktop-virtual", kcm: "kcm_kwin_virtualdesktops", k: "workspaces desktops" },
            { t: "Screen edges", d: "Hot corners and edge actions", i: "preferences-system-windows", kcm: "kcm_kwinscreenedges", k: "corners snap" },
            { t: "Window switching", d: "Alt+Tab appearance", i: "preferences-system-windows", kcm: "kcm_kwintabbox", k: "alt tab task switcher" },
            { t: "About", d: "Device specifications, PC name", i: "help-about", kcm: "kcm_about-distro", k: "pc name hostname rename specs version" }
        ] },
        { id: "devices", name: "Bluetooth & devices", icon: "preferences-system-bluetooth", items: [
            { t: "Bluetooth", d: "Pair and manage Bluetooth devices", i: "preferences-system-bluetooth", kcm: "kcm_bluetooth", k: "bluetooth pair headphones" },
            { t: "Mouse", d: "Pointer speed, buttons, scrolling", i: "input-mouse", kcm: "kcm_mouse", k: "pointer cursor speed" },
            { t: "Touchpad", d: "Taps, gestures, scrolling", i: "input-touchpad", kcm: "kcm_touchpad", k: "trackpad gestures" },
            { t: "Keyboard", d: "Layouts and keys", i: "input-keyboard", kcm: "kcm_keyboard", k: "layout typing keys" },
            { t: "Printers & scanners", d: "Add and manage printers", i: "printer", kcm: "kcm_printer_manager", k: "print" },
            { t: "Game controllers", d: "Gamepads and joysticks", i: "input-gamepad", kcm: "kcm_gamecontroller", k: "gamepad joystick controller" }
        ] },
        { id: "network", name: "Network & internet", icon: "preferences-system-network", items: [
            { t: "Wi-Fi & network", d: "Wi-Fi, Ethernet, VPN, hotspot", i: "network-wireless", kcm: "kcm_networkmanagement", k: "wifi wireless ethernet vpn internet" },
            { t: "Proxy", d: "Proxy server for apps", i: "preferences-system-network-proxy", kcm: "kcm_proxy", k: "proxy" },
        ] },
        { id: "personalization", name: "Personalization", icon: "preferences-desktop-theme", items: [
            { t: "Background", d: "Pictures, slideshow, solid colour", i: "preferences-desktop-wallpaper", kcm: "kcm_wallpaper", k: "wallpaper background picture" },
            { t: "Colors", d: "Dark and light mode, accent colour", i: "preferences-desktop-color", kcm: "kcm_colors", k: "dark light accent color colour" },
            { t: "Themes", d: "Global theme for the whole desktop", i: "preferences-desktop-theme-global", kcm: "kcm_lookandfeel", k: "theme look" },
            { t: "Lock screen", d: "Lock screen picture and timeout", i: "system-lock-screen", kcm: "kcm_screenlocker", k: "lock wallpaper" },
            { t: "Fonts", d: "Font family and size", i: "preferences-desktop-font", kcm: "kcm_fonts", k: "text font" },
            { t: "Icons", d: "Icon theme", i: "preferences-desktop-icons", kcm: "kcm_icons", k: "icons" },
            { t: "Cursors", d: "Mouse pointer style and size", i: "preferences-desktop-cursors", kcm: "kcm_cursortheme", k: "pointer cursor" }
        ] },
        { id: "apps", name: "Apps", icon: "applications-all", items: [
            { t: "Default apps", d: "Browser, mail, music, video", i: "preferences-desktop-default-applications", kcm: "kcm_componentchooser", k: "default browser" },
            { t: "File associations", d: "Which app opens each file type", i: "preferences-desktop-filetype-association", kcm: "kcm_filetypes", k: "file types open with" },
            { t: "Startup apps", d: "Apps that start when you sign in", i: "preferences-system-startup", kcm: "kcm_autostart", k: "autostart startup login" },
            { t: "App Store", d: "Install and remove apps", i: "plasmadiscover", cmd: "kstart --application io.github.kolunmi.Bazaar", k: "install store bazaar flatpak" }
        ] },
        { id: "accounts", name: "Accounts", icon: "preferences-system-users", items: [
            { t: "Your info", d: "Name and account picture", i: "user-identity", kcm: "kcm_users", k: "account picture avatar name" },
            { t: "Sign-in options", d: "Password", i: "preferences-desktop-user-password", kcm: "kcm_users", k: "password sign in login" },
            { t: "Online accounts", d: "Google, Nextcloud and more", i: "preferences-online-accounts", kcm: "kcm_kaccounts", k: "online accounts cloud" }
        ] },
        { id: "time", name: "Time & language", icon: "preferences-system-time", items: [
            { t: "Date & time", d: "Time zone, clock", i: "preferences-system-time", kcm: "kcm_clock", k: "clock time zone date" },
            { t: "Language & region", d: "Language, formats, region", i: "preferences-desktop-locale", kcm: "kcm_regionandlang", k: "language region locale format" },
            { t: "Typing", d: "Keyboard layouts and input", i: "preferences-desktop-keyboard", kcm: "kcm_keyboard", k: "input method layout" }
        ] },
        { id: "gaming", name: "Gaming", icon: "applications-games", items: [
            { t: "Game controllers", d: "Gamepads and joysticks", i: "input-gamepad", kcm: "kcm_gamecontroller", k: "gamepad controller joystick" },
            { t: "Steam", d: "Open Steam", i: "applications-games", cmd: "kstart --application steam", k: "steam games" }
        ] },
        { id: "accessibility", name: "Accessibility", icon: "preferences-desktop-accessibility", items: [
            { t: "Accessibility", d: "Bell, modifier keys, screen reader", i: "preferences-desktop-accessibility", kcm: "kcm_access", k: "screen reader sticky keys" },
            { t: "Text size", d: "Make text bigger", i: "preferences-desktop-font", kcm: "kcm_fonts", k: "text size font bigger" },
            { t: "Visual effects", d: "Desktop effects and animations", i: "preferences-desktop-effects", kcm: "kcm_kwin_effects", k: "effects animations transparency" },
            { t: "Night light", d: "Warmer colours at night", i: "preferences-desktop-display-color", kcm: "kcm_nightlight", k: "night light blue light" }
        ] },
        { id: "privacy", name: "Privacy & security", icon: "preferences-security", items: [
            { t: "Screen lock", d: "Lock automatically, require password", i: "system-lock-screen", kcm: "kcm_screenlocker", k: "lock password security" },
            { t: "Recent files", d: "Remember recently used files", i: "document-open-recent", kcm: "kcm_recentFiles", k: "history recent activity" },
            { t: "App permissions", d: "What Flatpak apps may access", i: "preferences-security", kcm: "kcm_app-permissions", k: "permissions flatpak camera microphone" }
        ] },
        { id: "updates", name: "Updates", icon: "system-software-update", items: [
            { t: "Check for updates", d: "Updates are manual: open the Updates app and run it when you choose", i: "system-software-update", cmd: "kstart --application io.github.rfrench3.bazzite-updater", k: "update upgrade windows update" },
            { t: "All settings (advanced)", d: "Every KDE setting in System Settings", i: "preferences-system", cmd: "systemsettings", k: "advanced all control panel kde" }
        ] }
    ]

    readonly property var currentCategory: categories.find(c => c.id === page) || categories[0]

    readonly property var searchResults: {
        const q = query.trim().toLowerCase();
        if (q === "") {
            return [];
        }
        let out = [];
        for (const c of categories) {
            for (const it of c.items) {
                const hay = (it.t + " " + it.d + " " + (it.k || "") + " " + c.name).toLowerCase();
                if (hay.indexOf(q) >= 0) {
                    out.push(it);
                }
            }
        }
        return out;
    }

    function run(cmd) {
        // Background it so the executable source finishes at once and can be reused.
        exec.connectSource(cmd + " >/dev/null 2>&1 &");
    }

    function openKcm(id) {
        KCMUtils.KCMLauncher.openSystemSettings(id);
    }

    function openItem(it) {
        if (it.kcm) {
            openKcm(it.kcm);
        } else if (it.info) {
            KCMUtils.KCMLauncher.openInfoCenter(it.info);
        } else if (it.cmd) {
            run(it.cmd);
        }
    }

    function setWallpaper(url) {
        wallpaper = url;
        run("plasma-apply-wallpaperimage '" + url.replace("file://", "") + "'");
    }

    function setColorMode(mode) {
        colorMode = mode;
        run(mode === "Light" ? "plasma-apply-colorscheme BreezeLight" : "plasma-apply-colorscheme BlackGlass");
    }

    preferredRepresentation: fullRepresentation

    KCoreAddons.KUser {
        id: kuser
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            const out = (data["stdout"] || "").trim();
            if (sourceName === app.modelCmd) {
                app.modelName = out;
            } else if (sourceName === app.colorCmd) {
                app.colorMode = out.indexOf("Light") >= 0 ? "Light" : "Dark";
            }
            disconnectSource(sourceName);
        }
    }

    Component.onCompleted: {
        exec.connectSource(modelCmd);
        exec.connectSource(colorCmd);
    }

    // plasmawindowed only honours the minimum size; open at the preferred size the first time
    // (a saved window geometry is restored by plasmawindowed after this and wins).
    readonly property var hostWindow: Window.window
    onHostWindowChanged: {
        if (hostWindow && hostWindow.width < 1000) {
            hostWindow.width = 1100;
            hostWindow.height = 720;
        }
    }

    fullRepresentation: Rectangle {
        id: shell
        Layout.minimumWidth: 800
        Layout.minimumHeight: 560
        Layout.preferredWidth: 1100
        Layout.preferredHeight: 720
        color: app.pageColor

        // Top bar: title on the left, "Find a setting" in the middle like Windows 11.
        Item {
            id: topBar
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 56

            GText {
                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                text: "Settings"
                dim: true
            }

            Rectangle {
                id: searchBox
                anchors.centerIn: parent
                width: Math.min(520, parent.width - 360)
                height: 34
                radius: 8
                gradient: Gradient {
                    GradientStop { position: 0; color: app.glassTop }
                    GradientStop { position: 1; color: app.glassBottom }
                }
                border.width: 1
                border.color: searchInput.activeFocus ? app.accent : app.rim

                Kirigami.Icon {
                    id: searchIcon
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    width: 16
                    height: 16
                    source: "edit-find"
                    color: app.textDim
                    isMask: true
                }

                TextInput {
                    id: searchInput
                    anchors { left: searchIcon.right; leftMargin: 8; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    color: app.textColor
                    selectionColor: app.selection
                    selectedTextColor: "white"
                    font.family: Kirigami.Theme.defaultFont.family
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                    clip: true
                    focus: true
                    activeFocusOnTab: true
                    Accessible.role: Accessible.EditableText
                    Accessible.name: "Find a setting"
                    onTextChanged: app.query = text
                    onAccepted: {
                        if (app.searchResults.length > 0) {
                            app.openItem(app.searchResults[0]);
                        }
                    }
                    Keys.onEscapePressed: text = ""

                    GText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Find a setting"
                        dim: true
                        visible: searchInput.text.length === 0
                    }
                }
            }
        }

        // Sidebar
        ColumnLayout {
            id: sidebar
            anchors { left: parent.left; top: topBar.bottom; bottom: parent.bottom; leftMargin: 12 }
            width: 270
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.bottomMargin: 8
                spacing: 12

                Item {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    Kirigami.ShadowedImage { // round account picture (Kirigami.Avatar lives in an add-on module Mountain does not ship)
                        anchors.fill: parent
                        visible: kuser.faceIconUrl.toString() !== ""
                        source: kuser.faceIconUrl
                        fillMode: Image.PreserveAspectCrop
                        radius: width / 2
                        sourceSize: Qt.size(104, 104)
                    }
                    Kirigami.Icon {
                        anchors.fill: parent
                        visible: kuser.faceIconUrl.toString() === ""
                        source: "user-identity"
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    GText {
                        Layout.fillWidth: true
                        text: kuser.fullName || kuser.loginName
                        font.bold: true
                    }
                    GText {
                        Layout.fillWidth: true
                        text: "Local account"
                        dim: true
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                }
            }

            Repeater {
                model: app.categories
                delegate: QQC2.AbstractButton {
                    id: navButton
                    required property var modelData
                    readonly property bool current: app.page === modelData.id && app.query === ""
                    Layout.fillWidth: true
                    implicitHeight: 34
                    hoverEnabled: true
                    activeFocusOnTab: true
                    text: modelData.name
                    Accessible.name: modelData.name
                    onClicked: {
                        searchInput.text = "";
                        app.page = modelData.id;
                    }
                    Keys.onReturnPressed: clicked()

                    background: Rectangle {
                        radius: 6
                        color: navButton.current ? Qt.rgba(1, 1, 1, 0.08) : (navButton.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                        border.width: navButton.activeFocus ? 1 : 0
                        border.color: app.accent
                        Rectangle {
                            visible: navButton.current
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            width: 3
                            height: 16
                            radius: 1.5
                            color: app.accent
                        }
                    }
                    contentItem: RowLayout {
                        spacing: 12
                        Item { Layout.preferredWidth: 4 }
                        Kirigami.Icon {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            source: navButton.modelData.icon
                        }
                        GText {
                            Layout.fillWidth: true
                            text: navButton.modelData.name
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        // Content area
        Flickable {
            id: flick
            anchors { left: sidebar.right; right: parent.right; top: topBar.bottom; bottom: parent.bottom; leftMargin: 20 }
            clip: true
            contentWidth: width
            contentHeight: pageLoader.height + 40
            boundsBehavior: Flickable.StopAtBounds
            QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

            Loader {
                id: pageLoader
                width: Math.min(flick.width - 32, 1000)
                height: item ? item.implicitHeight : 0
                source: app.query !== "" || app.page !== "home" ? "ListPage.qml" : "HomePage.qml"
                onSourceChanged: flick.contentY = 0
            }
        }
    }
}
