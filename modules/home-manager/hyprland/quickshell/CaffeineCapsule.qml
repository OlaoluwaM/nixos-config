pragma ComponentBehavior: Bound

import QtQuick

BarCapsule {
    id: root

    required property CaffeineActions caffeineActions
    required property StatusController status

    width: Theme.capsuleHeight
    color: root.status.caffeineManual ? Theme.primary : Theme.capsuleColor(false, root.hovered)
    border.color: root.status.caffeineManual ? Theme.primary : Theme.capsuleBorderColor(false, root.hovered)

    ShellIcon {
        anchors.centerIn: parent
        name: "coffee"
        iconColor: root.status.caffeineManual ? Theme.primaryForeground : Theme.capsuleTextColor(false, root.hovered)
        implicitSize: 16
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
