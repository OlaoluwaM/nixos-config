pragma ComponentBehavior: Bound

import QtQuick

BarCapsule {
    id: root
    required property PopupController popups

    visible: root.popups.trayItemCount > 0
    width: root.popups.trayItemCount > 0 ? Theme.barControlHeight : 0
    active: root.popups.activePopup === "tray"

    ShellIcon {
        anchors.centerIn: parent
        name: "tray"
        iconColor: Theme.barControlTextColor(root.active, root.hovered, false)
        implicitSize: Theme.barIconSize
    }

    TapHandler {
        onTapped: root.popups.toggle("tray")
    }
}
