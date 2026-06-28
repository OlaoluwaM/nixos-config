import QtQuick
import QtQuick.Controls.Basic

// Shared slider skin for quick settings.
//
// Qt's Slider provides the behavior. This file only draws the track and handle
// so brightness and volume do not carry two copies of the same styling.
Slider {
    id: root

    property color accentColor: Theme.primary

    // Live value to track when the user isn't dragging. Bound through a Binding
    // (not `value:`) below, because Qt's Slider writes `value` imperatively on
    // drag — a plain `value:` binding would be destroyed on first drag, freezing
    // the slider against later media/brightness-key changes.
    property real externalValue: 0

    Binding {
        target: root
        property: "value"
        value: root.externalValue
        when: !root.pressed
        restoreMode: Binding.RestoreBindingOrValue
    }

    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        // Implicit sizes so the control reports a real height; without them the
        // Basic style collapses to padding and the drag hit-area is a thin strip.
        implicitWidth: 200
        implicitHeight: 6
        width: root.availableWidth
        height: 6
        radius: Theme.trackRadius
        color: Theme.surfaceVariant

        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: Theme.trackRadius
            color: root.accentColor
        }
    }

    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        implicitWidth: 16
        implicitHeight: 16
        width: 16
        height: 16
        radius: Theme.capsuleButtonRadius
        color: root.pressed ? root.accentColor : Theme.text

        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
                easing.type: Theme.easingType
                easing.bezierCurve: Theme.easingCurve
            }
        }
    }
}
