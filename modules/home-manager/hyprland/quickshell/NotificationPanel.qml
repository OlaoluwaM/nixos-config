pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: notifPanel
    required property var notifications
    property bool heightAnimationsReady: false
    property bool _tick: false

    spacing: 16

    Timer {
        interval: 150
        running: true
        repeat: false
        onTriggered: notifPanel.heightAnimationsReady = true
    }

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
            text: notifPanel.notifications.historyModel.count
            Layout.alignment: Qt.AlignBaseline
            color: Theme.textDim
            font.pixelSize: 13
            visible: notifPanel.notifications.historyModel.count > 0
        }

        Item { Layout.fillWidth: true }

        Text {
            text: qsTr("Clear")
            Layout.alignment: Qt.AlignBaseline
            color: clearMouse.containsMouse ? Theme.tertiary : Theme.textSecondary
            font.pixelSize: 13
            visible: notifPanel.notifications.historyModel.count > 0

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Easing.InOutQuad } }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: notifPanel.notifications.clearAll()
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: notifPanel.notifications.historyModel.count === 0

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
        visible: notifPanel.notifications.historyModel.count > 0
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: notifColumn
            width: notifFlickable.width
            spacing: 12

            Repeater {
                model: notifPanel.notifications.historyModel

                delegate: NotificationCard {
                    id: notifItem
                    required property int index
                    required property real timestamp

                    width: notifColumn.width
                    radius: 10
                    expandable: true
                    heightAnimationEnabled: notifPanel.heightAnimationsReady
                    backgroundColor: Theme.surfaceVariant
                    dismissHoverColor: Theme.base
                    timeText: {
                        void(notifPanel._tick);
                        return qsTr("· %1").arg(notifPanel.timeAgo(notifItem.timestamp));
                    }
                    onCardClicked: {
                        notifItem.expanded = !notifItem.expanded;
                    }
                    onDismissed: notifPanel.notifications.dismissHistory(notifItem.notifId)
                    onActionInvoked: function(index) {
                        notifPanel.notifications.invokeAction(notifItem.notifId, index);
                    }
                }
            }
        }
    }
}
