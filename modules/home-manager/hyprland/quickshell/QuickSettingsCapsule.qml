pragma ComponentBehavior: Bound

import QtQuick

BarCapsule {
    id: root
    required property PopupController popups

    width: Theme.barControlHeight
    active: root.popups.activePopup === "quickSettings"

    ShellIcon {
        anchors.centerIn: parent
        name: "settings"
        iconColor: Theme.barControlTextColor(root.active, root.hovered, false)
        implicitSize: Theme.barIconSize
    }

    TapHandler {
        onTapped: root.popups.toggle("quickSettings")
    }
}
