import QtQuick

// Small icon-only button used by popovers and bar controls.
//
// It intentionally owns hover, active, danger, and border styling. Without this
// component each panel has to repeat the same Rectangle + ShellIcon + MouseArea
// block, which makes simple color or sizing changes easy to miss.
Rectangle {
    id: root

    property string iconName: ""
    property string accessibleName: iconName
    property bool active: false
    property bool danger: false
    property bool bordered: false
    property int buttonSize: Theme.capsuleButtonSize
    property int buttonWidth: buttonSize
    property int buttonHeight: buttonSize
    property int iconSize: 15
    property color activeColor: root.danger ? Theme.error : Theme.primary
    property color activeIconColor: root.danger ? Theme.errorForeground : Theme.primaryForeground
    property color normalColor: "transparent"
    property color hoverColor: root.danger ? Theme.error : Theme.surfaceHover
    property color iconColor: root.active ? root.activeIconColor
        : mouseArea.containsMouse ? (root.danger ? Theme.error : Theme.text)
        : Theme.textSecondary
    readonly property bool hovered: mouseArea.containsMouse

    signal clicked(var mouse)

    implicitWidth: root.buttonWidth
    implicitHeight: root.buttonHeight
    radius: Theme.capsuleButtonRadius
    color: root.active ? root.activeColor
        : mouseArea.containsMouse && !root.bordered ? root.hoverColor
        : root.normalColor
    border.color: root.bordered
        ? (root.active ? root.activeColor : mouseArea.containsMouse ? root.hoverColor : Theme.outline)
        : "transparent"
    border.width: root.bordered ? 1 : 0
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName

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

    ShellIcon {
        anchors.centerIn: parent
        name: root.iconName
        iconColor: root.iconColor
        implicitSize: root.iconSize
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        onClicked: function(mouse) {
            root.clicked(mouse);
        }
    }
}
