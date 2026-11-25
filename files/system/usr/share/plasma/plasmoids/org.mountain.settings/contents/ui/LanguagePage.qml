import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Language & region: "Add a language" lists the interface languages this PC ships (KDE translations in
// /usr/share/locale) and choosing one writes plasma-localerc [Translations] LANGUAGE (English stays as the fallback).
ColumnLayout {
    id: lang
    spacing: 10
    property string current: "en_US"
    property var available: []
    property bool adding: false
    property bool changed: false

    readonly property string listCmd: "for f in /usr/share/locale/*/LC_MESSAGES/plasmashell.mo; do d=${f#/usr/share/locale/}; echo ${d%%/*}; done"
    readonly property string readCmd: "kreadconfig6 --file plasma-localerc --group Translations --key LANGUAGE --default \"${LANGUAGE:-${LANG:-en_US}}\""

    function label(code) {
        const l = Qt.locale(code);
        const n = l.nativeLanguageName || code;
        const t = code.indexOf("_") > 0 && l.nativeTerritoryName ? " (" + l.nativeTerritoryName + ")" : "";
        return n.charAt(0).toUpperCase() + n.slice(1) + t;
    }
    function setLanguage(code) { // code comes from the folder list below: letters, digits, _ @ - only
        if (!/^[A-Za-z0-9_@-]+$/.test(code)) {
            return;
        }
        // Bulgarian: Mountain's "bg@mountain" catalog (Windows' Bulgarian names) first. Plasma applies this value after the session env
        // scripts, so mountain-names.sh alone was overwritten (vm-test 45429082715: LANGUAGE=bg:en_US)
        const value = code.indexOf("en") === 0 ? code : (code === "bg" ? "bg@mountain:bg:en_US" : code + ":en_US");
        app.sh("kwriteconfig6 --file plasma-localerc --group Translations --key LANGUAGE " + value + " # " + Date.now(), () => {
            lang.current = code;
            lang.changed = true;
            lang.adding = false;
        });
    }
    Component.onCompleted: {
        app.sh(readCmd, out => { current = (out.split(":")[0] || "en_US").replace("en@mountain", "en_US").replace("bg@mountain", "bg"); });
        app.sh(listCmd, out => {
            const codes = out.split("\n").filter(c => /^[A-Za-z0-9_@-]+$/.test(c));
            if (codes.indexOf("en_US") < 0) {
                codes.push("en_US"); // always there: it is the language the image ships
            }
            available = codes.map(c => ({ code: c, name: label(c) })).sort((a, b) => a.name.localeCompare(b.name));
        });
    }

    PageTitle { title: i18n("Language & region") }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        CardHeader { title: i18n("Display language"); subtitle: i18n("Menus, settings and apps appear in this language") }
        SettingRow { text: lang.label(lang.current); description: lang.current; iconName: "preferences-desktop-locale"; chevron: false }
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 10
            GlassButton { text: lang.adding ? i18n("Cancel") : i18n("Add a language"); highlighted: !lang.adding; onClicked: lang.adding = !lang.adding }
            GText {
                Layout.fillWidth: true
                visible: lang.changed
                dim: true
                wrapMode: Text.WordWrap
                text: i18n("Sign out and back in to use %1.", lang.label(lang.current))
            }
            GlassButton {
                visible: lang.changed
                text: i18n("Sign out now")
                onClicked: app.run("qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logout")
            }
        }
    }

    GlassCard {
        Layout.fillWidth: true
        visible: lang.adding
        padding: 6
        CardHeader { title: i18n("Add a language"); subtitle: i18n("%1 languages are installed", lang.available.length) }
        Repeater {
            model: lang.adding ? lang.available : []
            delegate: SettingRow {
                required property var modelData
                text: modelData.name
                description: modelData.code
                chevron: false
                divider: true
                Accessible.checked: modelData.code === lang.current
                onClicked: lang.setLanguage(modelData.code)
            }
        }
    }
}
