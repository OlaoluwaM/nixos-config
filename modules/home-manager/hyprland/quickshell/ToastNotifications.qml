pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: toastWindow
    required property var shell

    color: "transparent"
    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"

    visible: toastWindow.shell.notificationPopupsModel.count > 0 && !toastWindow.shell.doNotDisturb
    implicitWidth: 424
    implicitHeight: 800
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
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
        spacing: 8
        interactive: false
        model: toastWindow.shell.notificationPopupsModel

        HoverHandler {
            onHoveredChanged: toastWindow.shell.toastsHovered = hovered
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

        delegate: Rectangle {
            id: toastItem
            required property int index
            required property int notifId
            required property string appName
            required property string summary
            required property string body
            required property bool hasActions
            required property string actionLabels
            required property int urgency

            width: toastList.width
            height: toastContent.implicitHeight + 38
            radius: Theme.cardRadius
            color: Theme.base
            border.color: Theme.outline
            border.width: 1
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 4
                color: toastItem.urgency === 2 ? Theme.error
                     : toastItem.urgency === 0 ? Theme.secondary
                     : Theme.primary
            }

            ColumnLayout {
                id: toastContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 20
                anchors.rightMargin: 14
                anchors.topMargin: 14
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: toastItem.appName
                        color: Theme.textSecondary
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: qsTr("· now")
                        color: Theme.textDim
                        font.pixelSize: 12
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: 8
                        color: toastDismissMouse.containsMouse ? Theme.surfaceVariant : "transparent"

                        ShellIcon {
                            anchors.centerIn: parent
                            name: "close"
                            iconColor: toastDismissMouse.containsMouse ? Theme.text : Theme.textSecondary
                            implicitSize: 14
                        }

                        MouseArea {
                            id: toastDismissMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: toastWindow.shell.dismissNotifPopup(toastItem.notifId)
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: toastItem.summary
                    color: Theme.text
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                }

                Text {
                    Layout.fillWidth: true
                    text: toastItem.body
                    color: Theme.textSecondary
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    visible: text !== ""
                }

                NotificationActions {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    hasActions: toastItem.hasActions
                    actionLabels: toastItem.actionLabels
                    urgency: toastItem.urgency
                    onActionInvoked: function(index) {
                        toastWindow.shell.invokeNotifAction(toastItem.notifId, index);
                    }
                }
            }
        }
    }
}
