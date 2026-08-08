pragma ComponentBehavior: Bound

import QtQuick

BarCapsule {
    id: root
    required property PopupController popups
    required property NotificationService notifications

    width: Theme.barControlHeight
    active: root.popups.activePopup === "notifications"
    urgent: root.notifications.hasCriticalNotifications

    ShellIcon {
        id: notifBellIcon
        anchors.centerIn: parent
        name: root.notifications.doNotDisturb ? "notificationsOff" : "notifications"
        iconColor: Theme.barControlTextColor(root.active, root.hovered, root.urgent)
        implicitSize: Theme.barIconSize
    }

    Rectangle {
        visible: root.notifications.historyModel.count > 0
        width: 7
        height: 7
        radius: 3.5
        color: root.urgent ? Theme.error : Theme.primary
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
