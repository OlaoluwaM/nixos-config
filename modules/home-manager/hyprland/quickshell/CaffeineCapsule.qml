pragma ComponentBehavior: Bound

import QtQuick

BarCapsule {
    id: root

    required property CaffeineActions caffeineActions
    required property StatusController status

    width: Theme.capsuleHeight
    active: root.status.caffeineManual
    color: root.status.caffeineManual ? Theme.primary : Theme.capsuleColor(false, root.hovered)
    border.color: root.status.caffeineManual ? Theme.primary : Theme.capsuleBorderColor(false, root.hovered)

    ShellIcon {
        anchors.centerIn: parent
        name: "coffee"
        iconColor: root.status.caffeineManual ? Theme.primaryForeground : Theme.capsuleTextColor(false, root.hovered)
        implicitSize: 16
        width: 20
    }

    MouseArea {
        id: caffeineMouse

        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.caffeineActions.toggleManual()
    }

    HoverTooltip {
        active: caffeineMouse.containsMouse
        text: root.status.caffeineManual ? qsTr("Caffeine on") : qsTr("Caffeine off")
        anchors {
            top: parent.bottom
            topMargin: 6
            horizontalCenter: parent.horizontalCenter
        }
    }
}
