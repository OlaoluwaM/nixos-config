pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

BarCapsule {
    id: root
    required property ConnectivityActions connectivityActions
    required property StatusController status

    // Display intent: the controller is "on" only when powered and not killed by
    // airplane mode. device is the first connected peer (or null) for the label.
    readonly property bool active: !root.status.airplaneMode && root.status.bluetoothPowered
    readonly property var device: root.status.bluetoothDevices.length > 0 ? root.status.bluetoothDevices[0] : null

    width: Math.max(Theme.capsuleHeight, btContent.implicitWidth + 20)
    opacity: root.status.airplaneMode ? 0.35 : 1.0

    Behavior on opacity { OpacityAnimator { duration: Theme.animNormal } }

    RowLayout {
        id: btContent
        anchors.centerIn: parent
        spacing: 5

        ShellIcon {
            name: root.active ? "bluetooth" : "bluetoothOff"
            iconColor: Theme.capsuleTextColor(false, root.hovered)
            implicitSize: 15
            Layout.alignment: Qt.AlignVCenter
        }

        MarqueeText {
            visible: root.active && root.device !== null
            // Append battery when the device reports it (audio gear often doesn't).
            text: root.device ? (root.device.batteryPercent !== null
                ? root.device.name + " " + root.device.batteryPercent + "%"
                : root.device.name) : ""
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
        onTapped: root.connectivityActions.runBluetoothCommand()
    }
}
