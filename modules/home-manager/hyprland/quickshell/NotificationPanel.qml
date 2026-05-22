pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: notifPanel
    required property var shell
    spacing: 16

    property bool _tick: false
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: notifPanel._tick = !notifPanel._tick
    }

    function timeAgo(ts) {
        let diff = Math.floor((Date.now() - ts) / 1000);
        if (diff < 60) return "now";
        if (diff < 3600) return Math.floor(diff / 60) + "m ago";
        if (diff < 86400) return Math.floor(diff / 3600) + "h ago";
        return Math.floor(diff / 86400) + "d ago";
    }

    RowLayout {
        Layout.fillWidth: true

        Text {
            text: qsTr("Notifications")
            Layout.alignment: Qt.AlignBaseline
            color: Theme.text
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }

        Text {
            text: notifPanel.shell.notificationHistoryModel.count
            Layout.alignment: Qt.AlignBaseline
            color: Theme.textDim
            font.pixelSize: 13
            visible: notifPanel.shell.notificationHistoryModel.count > 0
        }

        Item { Layout.fillWidth: true }

        Text {
            text: qsTr("Clear")
            Layout.alignment: Qt.AlignBaseline
            color: clearMouse.containsMouse ? Theme.tertiary : Theme.textSecondary
            font.pixelSize: 13
            visible: notifPanel.shell.notificationHistoryModel.count > 0

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Easing.InOutQuad } }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: notifPanel.shell.clearAllNotifications()
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: notifPanel.shell.notificationHistoryModel.count === 0

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 12

            ShellIcon {
                Layout.alignment: Qt.AlignHCenter
                name: "notifications"
                iconColor: Theme.textDim
                implicitSize: 28
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("All clear")
                color: Theme.textDim
                font.pixelSize: 14
            }
        }
    }

    Flickable {
        id: notifFlickable
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentHeight: notifColumn.implicitHeight
        clip: true
        visible: notifPanel.shell.notificationHistoryModel.count > 0
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: notifColumn
            width: notifFlickable.width
            spacing: 8

            Repeater {
                model: notifPanel.shell.notificationHistoryModel

                delegate: Rectangle {
                    id: notifItem
                    required property int index
                    required property int notifId
                    required property string appName
                    required property string summary
                    required property string body
                    required property real timestamp
                    required property bool hasActions
                    required property string actionLabels
                    required property int urgency

                    property bool expanded: false

                    width: notifColumn.width
                    height: notifContent.implicitHeight + 38
                    radius: 10
                    color: Theme.surfaceVariant
                    clip: true

                    Behavior on height {
                        NumberAnimation {
                            duration: 300
                            easing.type: Theme.easingType
                            easing.bezierCurve: Theme.easingCurve
                        }
                    }

                    MouseArea {
                        id: notifHoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: notifItem.expanded = !notifItem.expanded
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 4
                        color: notifItem.urgency === 2 ? Theme.error
                             : notifItem.urgency === 0 ? Theme.secondary
                             : Theme.primary
                    }

                    ColumnLayout {
                        id: notifContent
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
                                text: notifItem.appName
                                color: Theme.textSecondary
                                font.pixelSize: 12
                            }

                            Text {
                                text: "·"
                                color: Theme.textDim
                                font.pixelSize: 12
                            }

                            Text {
                                text: {
                                    void(notifPanel._tick);
                                    return notifPanel.timeAgo(notifItem.timestamp);
                                }
                                color: Theme.textDim
                                font.pixelSize: 12
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: 8
                                color: dismissMouse.containsMouse ? Theme.base : "transparent"
                                opacity: (notifHoverArea.containsMouse || dismissMouse.containsMouse) ? 1 : 0

                                Behavior on opacity { OpacityAnimator { duration: Theme.animFast } }

                                ShellIcon {
                                    anchors.centerIn: parent
                                    name: "close"
                                    iconColor: dismissMouse.containsMouse ? Theme.text : Theme.textSecondary
                                    implicitSize: 14
                                }

                                MouseArea {
                                    id: dismissMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: notifPanel.shell.dismissNotifHistory(notifItem.notifId)
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: notifItem.summary
                            color: Theme.text
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            wrapMode: notifItem.expanded ? Text.Wrap : Text.NoWrap
                            elide: notifItem.expanded ? Text.ElideNone : Text.ElideRight
                            textFormat: Text.PlainText
                        }

                        Text {
                            Layout.fillWidth: true
                            text: notifItem.body
                            color: Theme.textSecondary
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                            maximumLineCount: notifItem.expanded ? 100 : 2
                            elide: notifItem.expanded ? Text.ElideNone : Text.ElideRight
                            textFormat: Text.PlainText
                            visible: text !== ""
                        }

                        NotificationActions {
                            Layout.fillWidth: true
                            Layout.topMargin: 16
                            hasActions: notifItem.hasActions
                            actionLabels: notifItem.actionLabels
                            urgency: notifItem.urgency
                            onActionInvoked: function(index) {
                                notifPanel.shell.invokeNotifAction(notifItem.notifId, index);
                            }
                        }
                    }
                }
            }
        }
    }
}
