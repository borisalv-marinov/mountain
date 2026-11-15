import QtQuick
import QtQuick.Layouts

// Storage: each disk partition with its used and free space (df), and a button that opens File Explorer.
ColumnLayout {
    id: st
    spacing: 10
    property var disks: []

    function gb(b) { return b >= 1e12 ? (b / 1e12).toFixed(1) + " TB" : (b / 1e9).toFixed(1) + " GB"; }
    Component.onCompleted: app.sh("df -B1 --output=source,size,used,avail,target | awk 'NR > 1 && $1 ~ /^\\/dev\\// && !seen[$1]++ { t = $5; for (i = 6; i <= NF; i++) t = t \" \" $i; print $2 \"\\t\" $3 \"\\t\" $4 \"\\t\" t }'", out => {
        disks = out === "" ? [] : out.split("\n").map(r => { const f = r.split("\t"); return { size: +f[0], used: +f[1], free: +f[2], at: f[3] }; });
    })

    PageTitle { title: "Storage" }

    Repeater {
        model: st.disks
        delegate: GlassCard {
            id: card
            required property var modelData
            Layout.fillWidth: true
            padding: 6
            CardHeader { title: card.modelData.at === "/" || card.modelData.at === "/var" ? "This PC (" + card.modelData.at + ")" : card.modelData.at; subtitle: st.gb(card.modelData.used) + " used of " + st.gb(card.modelData.size) + " · " + st.gb(card.modelData.free) + " free" }
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 18
                Layout.rightMargin: 18
                Layout.bottomMargin: 14
                height: 8
                radius: 4
                color: Qt.rgba(1, 1, 1, 0.12)
                Rectangle { width: parent.width * Math.min(1, card.modelData.used / Math.max(1, card.modelData.size)); height: parent.height; radius: 4; color: app.accent }
            }
        }
    }

    GText { visible: st.disks.length === 0; text: "No drives found."; dim: true }
    GlassButton { text: "Open File Explorer"; highlighted: true; onClicked: app.run("/usr/libexec/mountain-explorer") }
}
