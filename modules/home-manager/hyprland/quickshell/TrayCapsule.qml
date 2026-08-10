pragma ComponentBehavior: Bound

import QtQuick

BarCapsule {
    id: root
    required property PopupController popups

    visible: root.popups.trayItemCount > 0
    width: root.popups.trayItemCount > 0 ? Theme.capsuleHeight : 0
    active: root.popups.activePopup === "tray"

    ShellIcon {
        anchors.centerIn: parent
        name: "tray"
        iconColor: Theme.capsuleTextColor(root.popups.activePopup === "tray", root.hovered)
        implicitSize: 16
    }

    TapHandler {
        onTapped: root.popups.toggle("tray")
    }
}
