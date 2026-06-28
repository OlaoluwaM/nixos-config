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
            // Sorted by id so the dots always read left-to-right numerically —
            // Hyprland.workspaces is in creation order, not necessarily sorted.
            model: [...Hyprland.workspaces.values].sort((a, b) => a.id - b.id)

            delegate: Item {
                id: wsDelegate
                required property var modelData

                property bool isActive: Hyprland.focusedMonitor !== null
                    && Hyprland.focusedMonitor.activeWorkspace !== null
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
                    Behavior on opacity { OpacityAnimator { duration: Theme.animFade; easing.type: Theme.easingType; easing.bezierCurve: Theme.easingCurve } }
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

        // Index of the focused monitor's active workspace, or -1 when there
        // isn't one in the list — no monitor/workspace focused yet, or a
        // special/scratchpad workspace. -1 hides the highlight rather than
        // parking it on the first dot.
        readonly property int activeIndex: {
            if (!Hyprland.focusedMonitor || !Hyprland.focusedMonitor.activeWorkspace) return -1;
            let activeId = Hyprland.focusedMonitor.activeWorkspace.id;
            for (let i = 0; i < wsRepeater.count; i++) {
                let item = wsRepeater.itemAt(i);
                if (item && item.modelData.id === activeId) return i;
            }
            return -1;
        }

        // The active delegate itself. Driving x/y off its real geometry keeps
        // the highlight aligned even if the dot size or row spacing changes —
        // no hardcoded pitch to drift out of sync. Reads count so it
        // re-resolves as delegates are created/destroyed.
        readonly property Item activeItem: {
            wsRepeater.count;
            return wsHighlight.activeIndex >= 0
                ? wsRepeater.itemAt(wsHighlight.activeIndex)
                : null;
        }

        visible: wsHighlight.activeItem !== null
        width: 10
        height: 10
        radius: 5
        color: Theme.primary
        x: wsHighlight.activeItem
            ? workspaceRow.x + wsHighlight.activeItem.x
                + (wsHighlight.activeItem.width - wsHighlight.width) / 2
            : workspaceRow.x
        y: wsHighlight.activeItem
            ? workspaceRow.y + wsHighlight.activeItem.y
                + (wsHighlight.activeItem.height - wsHighlight.height) / 2
            : workspaceRow.y

        Behavior on x {
            id: wsHighlightAnim
            enabled: false
            NumberAnimation {
                duration: Theme.animSpring
                easing.type: Theme.easingSpringType
                easing.overshoot: Theme.springOvershoot
            }
        }

        Component.onCompleted: wsHighlightAnim.enabled = true
    }
}
