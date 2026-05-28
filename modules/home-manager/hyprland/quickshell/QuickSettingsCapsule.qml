pragma ComponentBehavior: Bound

import QtQuick

BarCapsule {
    id: root
    required property PopupController popups

    width: Theme.capsuleHeight
    active: root.popups.activePopup === "quickSettings"

    ShellIcon {
        anchors.centerIn: parent
        name: "quick"
        iconColor: Theme.capsuleTextColor(root.popups.activePopup === "quickSettings", root.hovered)
        implicitSize: 17
    }

    TapHandler {
        onTapped: root.popups.toggle("quickSettings")
    }
}
