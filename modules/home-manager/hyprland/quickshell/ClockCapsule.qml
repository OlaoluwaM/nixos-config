pragma ComponentBehavior: Bound

import QtQuick

BarCapsule {
    id: root
    required property PopupController popups
    required property StatusController status
    property bool compact: false
    readonly property var clockParts: root.status.clockText.split(" ")
    readonly property bool clockHasWeekday: root.clockParts.length >= 5
    readonly property string dateText: root.clockHasWeekday
        ? root.clockParts.slice(0, 3).join(" ")
        : (root.clockParts.length >= 4 ? root.clockParts.slice(0, 2).join(" ") : root.status.clockText)
    readonly property string timeText: root.clockHasWeekday
        ? root.clockParts.slice(3).join(" ")
        : (root.clockParts.length >= 4 ? root.clockParts.slice(2).join(" ") : "")
    readonly property real expandedWidth: dateLabel.implicitWidth
        + (root.timeText.length > 0 ? clockRow.spacing + timeLabel.implicitWidth : 0)
        + 24

    width: Math.max(Theme.barControlHeight, clockRow.implicitWidth + 24)
    active: root.popups.activePopup === "calendar"

    Row {
        id: clockRow
        anchors.centerIn: parent
        spacing: 8

        StyledText {
            id: dateLabel
            visible: !root.compact
            text: root.dateText
            color: Theme.barControlTextColor(root.active, root.hovered, false)
            font.pixelSize: Theme.barFontBody
            font.weight: Font.DemiBold

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingType; easing.bezierCurve: Theme.easingCurve } }
        }

        StyledText {
            id: timeLabel
            visible: root.timeText.length > 0
            text: root.timeText
            color: Theme.barControlTextColor(root.active, root.hovered, false)
            font.pixelSize: Theme.barFontBody
            font.weight: Font.DemiBold

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingType; easing.bezierCurve: Theme.easingCurve } }
        }
    }

    TapHandler {
        onTapped: root.popups.toggleAt("calendar", root.mapToItem(null, root.width / 2, 0).x)
    }
}
