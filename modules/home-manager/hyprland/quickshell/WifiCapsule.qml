pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// NOTE: Wi-Fi only for now. It always uses the Wi-Fi ("network") glyph and does
// not yet distinguish or handle Ethernet, even though status.networkName /
// networkOnline come from the primary connection (which could be Ethernet). The
// status script already exposes network.primary.type ("wifi" | "ethernet") if/
// when this grows Ethernet support.
BarCapsule {
    id: root
    required property ConnectivityActions connectivityActions
    required property StatusController status

    // Display intent: show a live connection only when a link is up AND the
    // radios are not killed. airplaneMode stays separate below to drive dimming.
    readonly property bool connected: !root.status.airplaneMode && root.status.networkOnline

    width: Math.max(Theme.capsuleHeight, wifiContent.implicitWidth + 28)
    opacity: root.status.airplaneMode ? 0.35 : 1.0

    Behavior on opacity { OpacityAnimator { duration: Theme.animNormal } }

    RowLayout {
        id: wifiContent
        anchors.centerIn: parent
        spacing: 5

        ShellIcon {
            name: root.connected ? "network" : "networkOff"
            iconColor: Theme.capsuleTextColor(false, root.hovered)
            implicitSize: 15
            Layout.alignment: Qt.AlignVCenter
        }

        MarqueeText {
            visible: root.connected
            text: root.status.networkName
            color: Theme.capsuleTextColor(false, root.hovered)
            font.pixelSize: 13
            font.weight: Font.DemiBold
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: 120
            Layout.preferredWidth: Math.min(implicitWidth, 120)
            Layout.preferredHeight: implicitHeight
        }
    }

    TapHandler {
        onTapped: root.connectivityActions.runNetworkCommand()
    }
}
