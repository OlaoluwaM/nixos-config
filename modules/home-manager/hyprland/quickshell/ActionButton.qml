import QtQuick
import QtQuick.Layouts

// Text button for short commands such as notification actions and media keys.
//
// This is deliberately small: panels still decide what the button does, while
// this component keeps the common hover and danger styling in one place.
Rectangle {
    id: root

    property string label: ""
    property string accessibleName: label
    property bool danger: false
    property bool filled: true
    property color accentColor: root.danger ? Theme.error : Theme.primary
    property color textColor: root.filled ? (root.danger ? Theme.errorForeground : Theme.primaryForeground) : Theme.text
    property color hoverTextColor: root.filled ? root.textColor : Theme.text
    property color unfilledColor: Theme.surfaceVariant
    property color unfilledHoverColor: root.danger ? Theme.error : Theme.surfaceHover
    property color unfilledBorderColor: Theme.outline
    property color unfilledHoverBorderColor: root.danger ? Theme.error : Theme.outline
    readonly property bool hovered: actionMouse.containsMouse
    property int horizontalPadding: 32
    property int buttonHeight: 30

    signal clicked(var mouse)

    implicitWidth: actionLabel.implicitWidth + root.horizontalPadding
    implicitHeight: root.buttonHeight
    radius: Theme.capsuleButtonRadius
    color: root.filled ? root.accentColor
        : root.hovered ? root.unfilledHoverColor
        : root.unfilledColor
    border.color: root.filled ? root.accentColor
        : root.hovered ? root.unfilledHoverBorderColor
        : root.unfilledBorderColor
    border.width: root.filled ? 0 : 1
    opacity: root.filled && !root.hovered ? 0.85 : 1.0
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName
    Layout.preferredHeight: root.buttonHeight

    Behavior on opacity {
        OpacityAnimator {
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

    StyledText {
        id: actionLabel

        anchors.centerIn: parent
        text: root.label
        color: root.hovered ? root.hoverTextColor : root.textColor
        font.pixelSize: Theme.fontCaption
        font.weight: Font.DemiBold
        textFormat: Text.PlainText

        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
                easing.type: Theme.easingType
                easing.bezierCurve: Theme.easingCurve
            }
        }
    }

    MouseArea {
        id: actionMouse

        anchors.fill: parent
        hoverEnabled: true
        onClicked: function(mouse) {
            root.clicked(mouse);
        }
    }
}
