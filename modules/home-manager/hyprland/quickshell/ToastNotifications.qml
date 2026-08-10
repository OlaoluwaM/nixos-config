pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property NotificationService notifications

    color: "transparent"
    aboveWindows: true
    visible: root.notifications.popupModel.count > 0 && !root.notifications.doNotDisturb
    implicitWidth: 424
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"

    // Clip input to the actual toast stack. The window spans the full screen
    // height/right edge, so without this the empty space below the toasts both
    // steals clicks and (via the list's HoverHandler) freezes toast timeouts.
    mask: Region { item: toastList }

    anchors {
        top: true
        bottom: true
        right: true
    }

    ListView {
        id: toastList
        width: 400
        // Size to the visible cards (capped to available height) so the mask and
        // the HoverHandler cover only the stack, not the empty space below it.
        height: Math.min(contentHeight, parent.height - 58)
        spacing: 12
        interactive: false
        model: root.notifications.popupModel
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 58
            rightMargin: 12
        }

        HoverHandler {
            onHoveredChanged: root.notifications.popupsHovered = hovered
        }

        add: Transition {
            OpacityAnimator { from: 0; to: 1; duration: Theme.animFade; easing.type: Theme.easingType; easing.bezierCurve: Theme.easingDecel }
        }

        remove: Transition {
            OpacityAnimator { from: 1; to: 0; duration: Theme.animFade; easing.type: Theme.easingType; easing.bezierCurve: Theme.easingAccel }
        }

        displaced: Transition {
            NumberAnimation { properties: "y"; duration: Theme.animFade; easing.type: Theme.easingType; easing.bezierCurve: Theme.easingCurve }
        }

        delegate: NotificationCard {
            id: toastItem

            width: toastList.width
            verticalPadding: 22
            contentCentered: true
            dismissAlwaysVisible: true
            backgroundColor: Theme.base
            strokeColor: Theme.outline
            strokeWidth: 1
            timeText: qsTr("· now")
            dismissHoverColor: Theme.surfaceVariant
            onDismissed: root.notifications.dismissPopup(toastItem.notifId)
            onActionInvoked: function(index) {
                root.notifications.invokeAction(toastItem.notifId, index);
            }
        }
    }
}
