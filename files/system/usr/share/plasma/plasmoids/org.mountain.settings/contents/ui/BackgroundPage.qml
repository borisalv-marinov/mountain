import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

// Personalization > Background, like Windows 11: preview, Picture / Solid color / Slideshow, photos, fit.
// Data and actions: /usr/libexec/mountain-background (reads once on open and after each change; no polling).
ColumnLayout {
    id: bg
    spacing: 10

    readonly property string helper: "/usr/libexec/mountain-background"
    readonly property string statusCmd: helper + " status"
    property string plugin: "org.kde.image"
    property string image: ""
    property int fill: 2
    property string solid: "#000000"
    property var pics: [] // [{ pkg, preview }]
    property string mode: plugin === "org.kde.color" ? "color" : plugin === "org.kde.slideshow" ? "slideshow" : "picture"

    readonly property var fits: [{ t: "Fill", v: 2 }, { t: "Fit", v: 1 }, { t: "Stretch", v: 0 }, { t: "Tile", v: 3 }, { t: "Center", v: 6 }]
    readonly property var swatches: ["#FF8C00", "#E81123", "#D13438", "#C30052", "#BF0077", "#9A0089", "#881798", "#744DA9",
                                     "#0078D4", "#0063B1", "#6B69D6", "#8764B8", "#00B7C3", "#038387", "#00B294", "#018574",
                                     "#00CC6A", "#10893E", "#7A7574", "#5D5A58", "#68768A", "#515C6B", "#4C4A48", "#000000"]
    // what the preview shows: a Mountain package's picture, or the file itself
    readonly property string previewUrl: {
        const p = pics.find(x => "file://" + x.pkg === image);
        return mode === "slideshow" ? (pics.length ? "file://" + pics[0].preview : "") : p ? "file://" + p.preview : image;
    }

    function q(x) { return "'" + String(x).split("'").join("'\\''") + "'"; }
    function act(args) { exec.connectSource(helper + " " + args + " 2>&1 # " + Date.now()); }
    function setPicture(path) {
        image = "file://" + path; // show it at once; the status read confirms it
        plugin = "org.kde.image";
        app.wallpaper = "file://" + (pics.find(x => x.pkg === path) || { preview: path }).preview;
        act("picture " + q(path) + " " + fill);
    }

    function switchTo(m) {
        if (m === "color") act("color " + q(solid));
        else if (m === "slideshow") act("slideshow");
        else setPicture(image !== "" ? image.replace("file://", "") : (pics[0] || { pkg: "/usr/share/wallpapers/mountain-silk/" }).pkg); // back to the last picture
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            if (source !== bg.statusCmd) {
                exec.connectSource(bg.statusCmd);
                return;
            }
            let p = [];
            for (const l of (data["stdout"] || "").split("\n")) {
                const i = l.indexOf("=");
                if (i <= 0) continue;
                const k = l.slice(0, i), v = l.slice(i + 1);
                if (k === "pic") { const f = v.split("|"); p.push({ pkg: f[0], preview: f[1] }); }
                else if (k === "plugin") bg.plugin = v;
                else if (k === "image") bg.image = v;
                else if (k === "fill") bg.fill = isNaN(parseInt(v)) ? 2 : parseInt(v); // 0 is Stretch
                else if (k === "color") bg.solid = v;
            }
            if (JSON.stringify(p) !== JSON.stringify(bg.pics)) bg.pics = p; // keep the tiles when nothing changed
        }
    }
    Component.onCompleted: exec.connectSource(statusCmd)

    GText {
        Layout.topMargin: 6
        Layout.bottomMargin: 6
        Layout.fillWidth: true
        text: "Personalization  ›  Background"
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2
        font.weight: Font.DemiBold
    }

    // Preview of the desktop: a small monitor with the taskbar line
    Rectangle {
        Layout.preferredWidth: 320
        Layout.preferredHeight: 190
        Layout.bottomMargin: 6
        radius: 8
        color: "#000000"
        border.width: 4
        border.color: "#3A3C42"
        Accessible.role: Accessible.Graphic
        Accessible.name: "Preview of your desktop"
        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: 6
            clip: true
            color: bg.mode === "color" ? bg.solid : "#000000"
            Image {
                anchors.fill: parent
                visible: bg.mode !== "color"
                source: bg.previewUrl
                sourceSize.width: 640
                asynchronous: true
                fillMode: bg.fill === 0 ? Image.Stretch : bg.fill === 1 ? Image.PreserveAspectFit : bg.fill === 3 ? Image.Tile : bg.fill === 6 ? Image.Pad : Image.PreserveAspectCrop
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 12
                color: Qt.rgba(0.05, 0.05, 0.06, 0.85)
            }
        }
    }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 14
            Kirigami.Icon { Layout.preferredWidth: 24; Layout.preferredHeight: 24; source: "preferences-desktop-wallpaper" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                GText { Layout.fillWidth: true; text: "Personalize your background" }
                GText {
                    Layout.fillWidth: true
                    dim: true
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    text: bg.mode === "slideshow" ? "A new picture every 30 minutes" : bg.mode === "color" ? "One color for your desktop" : "A picture you choose"
                }
            }
            Repeater {
                model: [{ t: "Picture", m: "picture" }, { t: "Solid color", m: "color" }, { t: "Slideshow", m: "slideshow" }]
                delegate: GlassButton {
                    required property var modelData
                    text: modelData.t
                    implicitWidth: 100
                    highlighted: bg.mode === modelData.m
                    Accessible.name: "Background: " + modelData.t
                    onClicked: if (bg.mode !== modelData.m) bg.switchTo(modelData.m)
                }
            }
        }

        // Picture: the Mountain photos and Browse photos
        ColumnLayout {
            visible: bg.mode === "picture"
            Layout.fillWidth: true
            Layout.leftMargin: 18
            Layout.rightMargin: 18
            Layout.bottomMargin: 14
            spacing: 10
            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
            GText { text: "Choose a photo" }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: bg.pics
                    delegate: QQC2.AbstractButton {
                        id: tile
                        required property var modelData
                        readonly property bool current: bg.image === "file://" + modelData.pkg
                        width: 120
                        height: 76
                        padding: 3
                        hoverEnabled: true
                        activeFocusOnTab: true
                        Accessible.name: "Set background " + modelData.pkg.split("/").filter(x => x).pop().replace(/-/g, " ")
                        onClicked: bg.setPicture(modelData.pkg)
                        Keys.onReturnPressed: clicked()
                        background: Rectangle {
                            radius: 6
                            color: "#000000"
                            border.width: tile.current || tile.visualFocus ? 2 : 1
                            border.color: tile.current || tile.visualFocus ? app.accent : (tile.hovered ? Qt.rgba(1, 1, 1, 0.4) : app.rim)
                        }
                        contentItem: Image {
                            source: "file://" + tile.modelData.preview
                            sourceSize.width: 240
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                GText { Layout.fillWidth: true; text: "Choose a photo from your PC"; dim: true }
                GlassButton { text: "Browse photos"; onClicked: bg.act("browse " + bg.fill) }
            }
            RowLayout {
                Layout.fillWidth: true
                GText { Layout.fillWidth: true; text: "Lock screen"; dim: true }
                GlassButton { text: "Use on lock screen too"; enabled: bg.image !== ""; onClicked: bg.act("lock " + bg.q(bg.image)) }
            }
        }

        // Solid color: swatches
        ColumnLayout {
            visible: bg.mode === "color"
            Layout.fillWidth: true
            Layout.leftMargin: 18
            Layout.rightMargin: 18
            Layout.bottomMargin: 14
            spacing: 10
            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
            GText { text: "Choose your background color" }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: bg.swatches
                    delegate: QQC2.AbstractButton {
                        id: sw
                        required property string modelData
                        readonly property bool current: bg.solid.toLowerCase() === modelData.toLowerCase()
                        width: 40
                        height: 40
                        hoverEnabled: true
                        activeFocusOnTab: true
                        Accessible.name: "Color " + modelData
                        onClicked: { bg.solid = modelData; bg.act("color " + bg.q(modelData)); }
                        Keys.onReturnPressed: clicked()
                        background: Rectangle {
                            radius: 6
                            color: sw.modelData
                            border.width: sw.current || sw.visualFocus ? 2 : 1
                            border.color: sw.current || sw.visualFocus ? "#FFFFFF" : (sw.hovered ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(1, 1, 1, 0.14))
                        }
                    }
                }
            }
        }

        // Slideshow: the album
        ColumnLayout {
            visible: bg.mode === "slideshow"
            Layout.fillWidth: true
            Layout.leftMargin: 18
            Layout.rightMargin: 18
            Layout.bottomMargin: 14
            spacing: 10
            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
            RowLayout {
                Layout.fillWidth: true
                GText { Layout.fillWidth: true; text: "Choose a picture album for a slideshow" }
                GlassButton { text: "Mountain pictures"; onClicked: bg.act("slideshow") }
                GlassButton { text: "Browse"; onClicked: bg.act("slideshow browse") }
            }
        }
    }

    // Choose a fit (pictures and slideshows)
    GlassCard {
        visible: bg.mode !== "color"
        Layout.fillWidth: true
        padding: 6
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 14
            Kirigami.Icon { Layout.preferredWidth: 24; Layout.preferredHeight: 24; source: "zoom-fit-best" }
            GText { Layout.fillWidth: true; text: "Choose a fit for your desktop image" }
            Flow {
                Layout.preferredWidth: Math.min(5 * 78, bg.width * 0.6)
                spacing: 6
                Repeater {
                    model: bg.fits
                    delegate: GlassButton {
                        required property var modelData
                        text: modelData.t
                        implicitWidth: 72
                        highlighted: bg.fill === modelData.v
                        Accessible.name: "Fit: " + modelData.t
                        onClicked: { bg.fill = modelData.v; bg.act("fit " + modelData.v); }
                    }
                }
            }
        }
    }
}
