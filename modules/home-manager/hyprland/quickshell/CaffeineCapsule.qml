pragma ComponentBehavior: Bound

import QtQuick

BarCapsule {
    id: root

    required property CaffeineActions caffeineActions
    required property StatusController status

    width: Theme.barControlHeight
    active: root.status.caffeineManual

    ShellIcon {
        anchors.centerIn: parent
        // Swap to the slashed glyph when caffeine is off, like the network/bluetooth
        // capsules. The active background colour still reinforces the on state.
        name: root.status.caffeineManual ? "coffee" : "coffeeOff"
        iconColor: Theme.barControlTextColor(root.active, root.hovered, false)
        implicitSize: Theme.barIconSize
    }

    TapHandler {
        onTapped: root.caffeineActions.toggleManual()
    }

    HoverTooltip {
        active: root.hovered
        text: root.status.caffeineManual ? qsTr("Caffeine on") : qsTr("Caffeine off")
        anchors {
            top: parent.bottom
            topMargin: 6
            horizontalCenter: parent.horizontalCenter
        }
    }
}
