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

    // Opt-in for capsules that represent a *live radio/link* (wifi, bluetooth):
    // when active they fill with the soft primary→secondary accent wash instead
    // of the plain tint other active capsules get, so they read as a brighter
    // "live" chip while staying in-palette. The gradient is defined once here
    // (stop colours come from Theme) rather than copied into each radio capsule.
    property bool accentGradient: false
    readonly property bool activeAccent: root.accentGradient && root.active
    readonly property bool hoverActive: root.respondToHover && root.hovered
    readonly property var accentGradientStops: Theme.capsuleGradient()
    readonly property Gradient accentFill: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: root.accentGradientStops.start }
        GradientStop { position: 1.0; color: root.accentGradientStops.end }
    }

    height: Theme.capsuleHeight
    radius: Theme.capsuleRadius
    color: Theme.capsuleColor(root.active, root.hoverActive)
    // Rectangle uses the gradient over `color` when one is set; only live radio
    // capsules supply one. While hovered, live radio capsules fall back to the
    // same active hover fill as the rest of the bar so feedback stays obvious.
    gradient: root.activeAccent && !root.hoverActive ? root.accentFill : null
    border.color: Theme.capsuleBorderColor(root.active, root.hoverActive)
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
