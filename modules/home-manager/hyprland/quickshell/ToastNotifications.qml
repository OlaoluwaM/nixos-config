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

    anchors {
        top: true
        bottom: true
        right: true
    }

    ListView {
        id: toastList
        width: 400
        height: parent.height - 58
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
            OpacityAnimator { from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }

        remove: Transition {
            OpacityAnimator { from: 1; to: 0; duration: 200; easing.type: Easing.OutCubic }
        }

        displaced: Transition {
            NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic }
        }

        delegate: NotificationCard {
            id: toastItem
            required property int index

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
