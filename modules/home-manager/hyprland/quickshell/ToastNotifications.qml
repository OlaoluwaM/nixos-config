pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: toastWindow
    required property var notifications

    color: "transparent"
    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"

    visible: toastWindow.notifications.popupModel.count > 0 && !toastWindow.notifications.doNotDisturb
    implicitWidth: 424
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        right: true
    }

    ListView {
        id: toastList
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 58
        anchors.rightMargin: 12
        width: 400
        height: parent.height - 58
        spacing: 12
        interactive: false
        model: toastWindow.notifications.popupModel

        HoverHandler {
            onHoveredChanged: toastWindow.notifications.popupsHovered = hovered
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
            onDismissed: toastWindow.notifications.dismissPopup(toastItem.notifId)
            onActionInvoked: function(index) {
                toastWindow.notifications.invokeAction(toastItem.notifId, index);
            }
        }
    }
}
