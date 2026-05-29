import QtQuick
import QtQuick.Controls.Basic

// Shared slider skin for quick settings.
//
// Qt's Slider provides the behavior. This file only draws the track and handle
// so brightness and volume do not carry two copies of the same styling.
Slider {
    id: root

    property color accentColor: Theme.primary

    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth
        height: 6
        radius: 3
        color: Theme.surfaceVariant

        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: 3
            color: root.accentColor
        }
    }

    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: 16
        height: 16
        radius: 8
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
