pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// Primary connectivity capsule. Shows the active link (Wi-Fi or Ethernet) and,
// when present, a trailing VPN shield layered on top. The link type comes from
// status.networkType; VPN is an independent overlay driven by status.vpnOn, so
// it composes with either link rather than replacing the icon.
//
// Note: this reflects the *primary* connection (the default-route device). If
// Wi-Fi and Ethernet are both up, only the primary is shown.
BarCapsule {
    id: root
    required property ConnectivityActions connectivityActions
    required property StatusController status

    // Display intent: show a live connection only when a link is up AND the
    // radios are not killed. airplaneMode stays separate below to drive dimming.
    readonly property bool connected: !root.status.airplaneMode && root.status.networkOnline
    readonly property bool ethernet: root.status.networkType === "ethernet"
    // VPN is only shown while there is also a live link for it to ride on.
    readonly property bool vpnActive: root.connected && root.status.vpnOn

    // A live link lights the capsule up: feed `connected` into the frame's
    // `active` and opt into the primary→secondary accent gradient, mirroring
    // BluetoothCapsule so the two radio capsules read identically.
    active: root.connected
    accentGradient: true

    width: Math.max(Theme.capsuleHeight, netContent.implicitWidth + 28)
    opacity: root.status.airplaneMode ? 0.35 : 1.0

    Behavior on opacity { OpacityAnimator { duration: Theme.animNormal; easing.type: Theme.easingType; easing.bezierCurve: Theme.easingCurve } }

    RowLayout {
        id: netContent
        anchors.centerIn: parent
        spacing: 5

        ShellIcon {
            name: !root.connected ? "networkOff" : (root.ethernet ? "ethernet" : "network")
            iconColor: Theme.capsuleTextColor(root.active, root.hovered)
            implicitSize: 15
            Layout.alignment: Qt.AlignVCenter
        }

        MarqueeText {
            visible: root.connected
            // Ethernet connection names ("Wired connection 1") aren't meaningful,
            // so show a plain label; Wi-Fi keeps its connection/SSID name.
            text: root.ethernet ? qsTr("Ethernet") : root.status.networkName
            color: Theme.capsuleTextColor(root.active, root.hovered)
            font.pixelSize: Theme.fontBody
            font.weight: Font.DemiBold
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: 120
            Layout.preferredWidth: Math.min(implicitWidth, 120)
            Layout.preferredHeight: implicitHeight
        }

        // VPN overlay: a small shield appended only while a tunnel is up. Layouts
        // skip invisible items, so it occupies no space when there is no VPN.
        ShellIcon {
            visible: root.vpnActive
            name: "vpn"
            iconColor: Theme.capsuleTextColor(root.active, root.hovered)
            implicitSize: 12
            Layout.alignment: Qt.AlignVCenter
        }
    }

    TapHandler {
        onTapped: root.connectivityActions.runNetworkCommand()
    }

    HoverTooltip {
        active: root.hovered && root.vpnActive
        text: root.status.vpnName.length > 0
            ? (root.status.vpnType.length > 0
                ? qsTr("VPN: %1 (%2)").arg(root.status.vpnName).arg(root.status.vpnType)
                : qsTr("VPN: %1").arg(root.status.vpnName))
            : qsTr("VPN active")
        anchors {
            top: parent.bottom
            topMargin: 6
            horizontalCenter: parent.horizontalCenter
        }
    }
}
