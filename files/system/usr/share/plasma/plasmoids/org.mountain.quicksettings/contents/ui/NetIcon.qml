// Panel icon for the network state (plasma-nm ConnectionIcon, as in plasma-nm applet/main.qml).
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.networkmanagement as PlasmaNM

Kirigami.Icon {
    PlasmaNM.NetworkStatus { id: networkStatus }
    PlasmaNM.ConnectionIcon { id: connectionIcon; connectivity: networkStatus.connectivity }

    source: connectionIcon.connectionIcon + "-symbolic"
    fallback: "network-wired-symbolic"
    Accessible.name: networkStatus.activeConnections
}
