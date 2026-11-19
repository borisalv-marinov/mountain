import QtQuick
import QtQuick.Layouts

// Printers: queues CUPS already has (lpstat); network printers show up here by themselves.
ColumnLayout {
    id: pr
    spacing: 10
    property var printers: [] // [{ name, status }]
    property string def: ""
    Component.onCompleted: app.sh("lpstat -p -d 2>/dev/null; true", out => {
        const l = out.split("\n");
        printers = l.filter(x => x.indexOf("printer ") === 0).map(x => { const w = x.split(" "); return { name: w[1], status: w.slice(2).join(" ").replace(/\.? *enabled since.*$/, "").replace(/^is /, "") }; });
        def = (l.find(x => x.indexOf("system default destination: ") === 0) || "").replace("system default destination: ", "");
    })

    PageTitle { title: i18n("Printers & scanners") }

    GlassCard {
        Layout.fillWidth: true
        padding: 6
        CardHeader { title: i18n("Printers"); subtitle: i18n("Printers on your network are added automatically") }
        GText { visible: pr.printers.length === 0; Layout.margins: 18; text: i18n("No printers yet. Join the same network as your printer, or plug it in by USB."); dim: true }
        Repeater {
            model: pr.printers
            delegate: SettingRow {
                required property var modelData
                required property int index
                text: modelData.name
                description: modelData.status + (modelData.name === pr.def ? i18n(" · Default") : "")
                iconName: "printer"
                chevron: false
                divider: index > 0
                trailing: GlassButton { text: i18n("Print test page"); onClicked: app.run("lp -d '" + modelData.name + "' /usr/share/cups/data/testprint") }
            }
        }
    }
}
