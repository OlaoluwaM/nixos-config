pragma ComponentBehavior: Bound

import QtQuick

BarCapsule {
    id: root
    required property PopupController popups
    required property StatusController status
    readonly property var clockParts: root.status.clockText.split(" ")
    readonly property bool clockHasWeekday: root.clockParts.length >= 5
    readonly property string dateText: root.clockHasWeekday
        ? root.clockParts.slice(0, 3).join(" ")
        : (root.clockParts.length >= 4 ? root.clockParts.slice(0, 2).join(" ") : root.status.clockText)
    readonly property string timeText: root.clockHasWeekday
        ? root.clockParts.slice(3).join(" ")
        : (root.clockParts.length >= 4 ? root.clockParts.slice(2).join(" ") : "")

    width: clockRow.implicitWidth + 36
    active: root.popups.activePopup === "calendar"

    Row {
        id: clockRow
        anchors.centerIn: parent
        spacing: 12

        StyledText {
            text: root.dateText
            color: Theme.capsuleTextColor(root.popups.activePopup === "calendar", root.hovered)
            font.pixelSize: Theme.fontMedium
            font.weight: Font.DemiBold

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingType; easing.bezierCurve: Theme.easingCurve } }
        }

        StyledText {
            visible: root.timeText.length > 0
            text: root.timeText
            color: Theme.capsuleTextColor(root.popups.activePopup === "calendar", root.hovered)
            font.pixelSize: Theme.fontMedium
            font.weight: Font.DemiBold

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingType; easing.bezierCurve: Theme.easingCurve } }
        }
    }

    TapHandler {
        onTapped: root.popups.toggle("calendar")
    }
}
