import QtQuick
import QtQuick.Layouts

// Storage: the main disk as "Local Disk (C:)" plus USB and extra drives, with used and free space (df), and a button that opens File Explorer.
ColumnLayout {
    id: st
    spacing: 10
    property var disks: []

    function gb(b) { return b >= 1e12 ? (b / 1e12).toFixed(1) + " TB" : (b / 1e9).toFixed(1) + " GB"; }
    // C: is the disk holding /var/home (like File Explorer); extra drives are the ones mounted under /run/media, /mnt (D:, E:, ...). /boot, /etc and bind mounts are not drives.
    Component.onCompleted: app.sh("{ df -B1 --output=size,used,avail /var/home | awk 'NR > 1 { print \"Local Disk (C:)\t\" $1 \"\t\" $2 \"\t\" $3 }'; df -B1 --output=size,used,avail,target | awk 'NR > 1 && $4 ~ \"^/(var/)?(run/media|mnt)/\" && !seen[$1 $2 $4]++ { printf \"%s (%c:)\\t%s\\t%s\\t%s\\n\",($4 ~ \"/media/\" ? \"USB Drive\" : \"Local Disk\"), 68 + n++, $1, $2, $3 }'; }", out => {
        disks = out === "" ? [] : out.split("\n").map(r => { const f = r.split("\t"); return { name: f[0], size: +f[1], used: +f[2], free: +f[3] }; });
    })

    PageTitle { title: i18n("Storage") }

    Repeater {
        model: st.disks
        delegate: GlassCard {
            id: card
            required property var modelData
            Layout.fillWidth: true
            padding: 6
            CardHeader { title: card.modelData.name; subtitle: i18n("%1 used of %2 · %3 free", st.gb(card.modelData.used), st.gb(card.modelData.size), st.gb(card.modelData.free)) }
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

    GText { visible: st.disks.length === 0; text: i18n("No drives found."); dim: true }
    GlassButton { text: i18n("Open File Explorer"); highlighted: true; onClicked: app.run("/usr/libexec/mountain-explorer") }
}
