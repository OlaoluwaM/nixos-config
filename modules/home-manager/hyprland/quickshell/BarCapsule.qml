import QtQuick

// A capsule is one framed block in the top bar.
//
// Most bar items share the same height, rounded corners, hover color, active
// color, and border animation. Keeping that frame here means future changes to
// the bar's basic shape only need one edit.
Rectangle {
    id: root

    default property alias content: contentHost.data
    property bool active: false
    property bool respondToHover: true
    readonly property bool hovered: hoverHandler.hovered
    property bool clipped: false

    height: Theme.capsuleHeight
    radius: Theme.capsuleRadius
    color: Theme.capsuleColor(root.active, root.respondToHover && root.hovered)
    border.color: Theme.capsuleBorderColor(root.active, root.respondToHover && root.hovered)
    border.width: 1
    clip: root.clipped

    Behavior on color {
        ColorAnimation {
            duration: Theme.animFast
            easing.type: Theme.easingType
            easing.bezierCurve: Theme.easingCurve
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: Theme.animFast
            easing.type: Theme.easingType
            easing.bezierCurve: Theme.easingCurve
        }
    }

    HoverHandler {
        id: hoverHandler
    }

    Item {
        id: contentHost
        anchors.fill: parent
    }
}
