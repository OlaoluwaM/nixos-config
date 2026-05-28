pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

BarCapsule {
    id: root
    required property ConnectivityActions connectivityActions
    required property StatusController status

    width: Math.max(Theme.capsuleHeight, wifiContent.implicitWidth + 28)
    opacity: root.status.airplaneMode ? 0.35 : 1.0

    Behavior on opacity { OpacityAnimator { duration: Theme.animNormal } }

    RowLayout {
        id: wifiContent
        anchors.centerIn: parent
        spacing: 5

        ShellIcon {
            name: root.status.airplaneMode || root.status.networkText === "Offline" ? "networkOff" : "network"
            iconColor: Theme.capsuleTextColor(false, root.hovered)
            implicitSize: 15
            Layout.alignment: Qt.AlignVCenter
        }

        MarqueeText {
            visible: !root.status.airplaneMode && !(root.status.networkText === "Offline")
            text: root.status.networkText
            color: Theme.capsuleTextColor(false, root.hovered)
            font.pixelSize: 13
            font.weight: Font.DemiBold
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: 120
            Layout.preferredWidth: Math.min(implicitWidth, 120)
            Layout.preferredHeight: implicitHeight
        }
    }

    MouseArea {
        id: wifiMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.connectivityActions.runNetworkCommand()
    }
}
