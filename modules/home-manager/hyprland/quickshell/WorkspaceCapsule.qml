pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland

Rectangle {
    id: root

    width: Math.max(36, workspaceRow.implicitWidth + 16)
    height: Theme.capsuleHeight
    radius: Theme.capsuleRadius
    color: Theme.surfaceVariant
    border.color: Theme.outline
    border.width: 1
    clip: true

    Behavior on width {
        NumberAnimation {
            duration: Theme.animFade
            easing.type: Theme.easingType
            easing.bezierCurve: Theme.easingCurve
        }
    }

    Row {
        id: workspaceRow
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            id: wsRepeater
            model: Hyprland.workspaces

            delegate: Item {
                id: wsDelegate
                required property var modelData

                property bool isActive: Hyprland.focusedMonitor !== null
                    && wsDelegate.modelData.id === Hyprland.focusedMonitor.activeWorkspace.id

                width: 18
                height: 18

                Rectangle {
                    anchors.centerIn: parent
                    width: !wsDelegate.isActive && wsMouse.containsMouse ? 8 : 6
                    height: width
                    radius: width / 2
                    color: !wsDelegate.isActive && wsMouse.containsMouse ? Theme.text : Theme.textSecondary
                    opacity: wsDelegate.isActive ? 0 : 1

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.animFade
                            easing.type: Theme.easingType
                            easing.bezierCurve: Theme.easingCurve
                        }
                    }
                    Behavior on color { ColorAnimation { duration: Theme.animFade; easing.type: Theme.easingType; easing.bezierCurve: Theme.easingCurve } }
                    Behavior on opacity { OpacityAnimator { duration: Theme.animFade } }
                }

                MouseArea {
                    id: wsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: wsDelegate.modelData.activate()
                }
            }
        }
    }

    Rectangle {
        id: wsHighlight

        property int activeIndex: {
            if (!Hyprland.focusedMonitor) return 0;
            let activeId = Hyprland.focusedMonitor.activeWorkspace.id;
            for (let i = 0; i < wsRepeater.count; i++) {
                let item = wsRepeater.itemAt(i);
                if (item && item.modelData.id === activeId) return i;
            }
            return 0;
        }

        visible: wsRepeater.count > 0
        width: 10
        height: 10
        radius: 5
        color: Theme.primary
        x: workspaceRow.x + activeIndex * 24 + 4
        y: workspaceRow.y + 4

        Behavior on x {
            id: wsHighlightAnim
            enabled: false
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutBack
                easing.overshoot: 1.4
            }
        }

        Component.onCompleted: wsHighlightAnim.enabled = true
    }
}
