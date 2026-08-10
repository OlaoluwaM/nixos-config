pragma ComponentBehavior: Bound

import QtQuick

BarCapsule {
    id: root
    required property PopupController popups
    required property NotificationService notifications

    width: Theme.capsuleHeight
    active: root.popups.activePopup === "notifications"

    ShellIcon {
        id: notifBellIcon
        anchors.centerIn: parent
        name: root.notifications.doNotDisturb ? "notificationsOff" : "notifications"
        iconColor: Theme.capsuleTextColor(root.popups.activePopup === "notifications", root.hovered)
        implicitSize: 15
    }

    Rectangle {
        visible: root.notifications.historyModel.count > 0
        width: 7
        height: 7
        radius: 3.5
        color: Theme.error
        anchors {
            left: notifBellIcon.right
            top: notifBellIcon.top
            leftMargin: -2
            topMargin: -3
        }
    }

    TapHandler {
        onTapped: root.popups.toggle("notifications")
    }
}
