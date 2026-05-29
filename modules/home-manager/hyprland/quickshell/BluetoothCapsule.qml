pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

BarCapsule {
    id: root
    required property ConnectivityActions connectivityActions
    required property StatusController status

    // Display intent: the radio is "on" only when powered and not killed by
    // airplane mode. device is the first connected peer (or null) for the label.
    // Named `powered` (not `active`) so it no longer shadows BarCapsule.active;
    // we feed it into the frame's `active` explicitly below, mirroring the
    // NetworkCapsule's `connected` wiring so the two radio capsules behave the same.
    readonly property bool powered: !root.status.airplaneMode && root.status.bluetoothPowered
    readonly property var device: root.status.bluetoothDevices.length > 0 ? root.status.bluetoothDevices[0] : null

    // Live radio lights the capsule up with the primary→secondary accent
    // gradient, matching NetworkCapsule so the two radio capsules read identically.
    active: root.powered
    accentGradient: true

    width: Math.max(Theme.capsuleHeight, btContent.implicitWidth + 20)
    opacity: root.status.airplaneMode ? 0.35 : 1.0

    Behavior on opacity { OpacityAnimator { duration: Theme.animNormal; easing.type: Theme.easingType; easing.bezierCurve: Theme.easingCurve } }

    RowLayout {
        id: btContent
        anchors.centerIn: parent
        spacing: 5

        ShellIcon {
            name: root.powered ? "bluetooth" : "bluetoothOff"
            iconColor: Theme.capsuleTextColor(root.active, root.hovered)
            implicitSize: 15
            Layout.alignment: Qt.AlignVCenter
        }

        MarqueeText {
            visible: root.powered && root.device !== null
            // Append battery when the device reports it (audio gear often doesn't).
            text: root.device ? (root.device.batteryPercent !== null
                ? root.device.name + " " + root.device.batteryPercent + "%"
                : root.device.name) : ""
            color: Theme.capsuleTextColor(root.active, root.hovered)
            font.pixelSize: Theme.fontBody
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
