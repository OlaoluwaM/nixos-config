pragma ComponentBehavior: Bound

import QtQuick

BarCapsule {
    id: root
    required property PopupController popups
    required property StatusController status

    width: clockRow.implicitWidth + 30
    active: root.popups.activePopup === "calendar"

    Row {
        id: clockRow
        anchors.centerIn: parent
        spacing: 10

        StyledText {
            text: {
                let parts = root.status.clockText.split(" ");
                return parts.slice(0, 2).join(" ");
            }
            color: Theme.capsuleTextColor(root.popups.activePopup === "calendar", root.hovered)
            font.pixelSize: 14
            font.weight: Font.DemiBold

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingType; easing.bezierCurve: Theme.easingCurve } }
        }

        StyledText {
            text: {
                let parts = root.status.clockText.split(" ");
                return parts.slice(2).join(" ");
            }
            color: Theme.capsuleTextColor(root.popups.activePopup === "calendar", root.hovered)
            font.pixelSize: 14
            font.weight: Font.DemiBold

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingType; easing.bezierCurve: Theme.easingCurve } }
        }
    }

    TapHandler {
        onTapped: root.popups.toggle("calendar")
    }
}
