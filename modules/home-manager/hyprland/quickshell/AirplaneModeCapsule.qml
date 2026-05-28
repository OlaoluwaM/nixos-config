pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: root
    required property StatusController status

    visible: root.status.airplaneMode
    width: root.status.airplaneMode ? Theme.capsuleHeight : 0
    height: Theme.capsuleHeight
    radius: Theme.capsuleRadius
    color: Theme.primary
    border.color: Theme.primary
    border.width: 1

    ShellIcon {
        anchors.centerIn: parent
        name: "airplane"
        iconColor: Theme.primaryContrast
        implicitSize: 15
    }
}
