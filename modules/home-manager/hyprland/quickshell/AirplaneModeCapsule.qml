pragma ComponentBehavior: Bound

import QtQuick

BarCapsule {
    id: root
    required property StatusController status

    visible: root.status.airplaneMode
    width: root.status.airplaneMode ? Theme.barControlHeight : 0
    active: root.status.airplaneMode

    ShellIcon {
        anchors.centerIn: parent
        name: "airplane"
        iconColor: Theme.barControlTextColor(root.active, root.hovered, false)
        implicitSize: Theme.barIconSize
    }
}
