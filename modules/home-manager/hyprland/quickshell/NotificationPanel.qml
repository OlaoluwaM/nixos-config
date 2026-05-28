pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property NotificationService notifications
    property bool heightAnimationsReady: false
    property bool _tick: false

    spacing: 16

    Timer {
        interval: 150
        running: true
        repeat: false
        onTriggered: root.heightAnimationsReady = true
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root._tick = !root._tick
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
            color: Theme.text
            font.pixelSize: 16
            font.weight: Font.DemiBold
            Layout.alignment: Qt.AlignBaseline
        }

        Text {
            text: root.notifications.historyModel.count
            color: Theme.textDim
            font.pixelSize: 13
            visible: root.notifications.historyModel.count > 0
            Layout.alignment: Qt.AlignBaseline
        }

        Item { Layout.fillWidth: true }

        Text {
            text: qsTr("Clear")
            color: clearMouse.containsMouse ? Theme.text : Theme.textSecondary
            font.pixelSize: 13
            visible: root.notifications.historyModel.count > 0
            Layout.alignment: Qt.AlignBaseline

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Easing.InOutQuad } }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.notifications.clearAll()
            }
        }
    }

    Item {
        visible: root.notifications.historyModel.count === 0
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 12

            ShellIcon {
                name: "notifications"
                iconColor: Theme.textDim
                implicitSize: 28
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: qsTr("All clear")
                color: Theme.textDim
                font.pixelSize: 14
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    Flickable {
        id: notifFlickable
        contentHeight: notifColumn.implicitHeight
        clip: true
        visible: root.notifications.historyModel.count > 0
        boundsBehavior: Flickable.StopAtBounds
        Layout.fillWidth: true
        Layout.fillHeight: true

        Column {
            id: notifColumn
            width: notifFlickable.width
            spacing: 12

            Repeater {
                model: root.notifications.historyModel

                delegate: NotificationCard {
                    id: notifItem
                    required property int index
                    required property real timestamp

                    width: notifColumn.width
                    radius: 10
                    expandable: true
                    heightAnimationEnabled: root.heightAnimationsReady
                    backgroundColor: Theme.surfaceVariant
                    dismissHoverColor: Theme.base
                    timeText: {
                        void(root._tick);
                        return qsTr("· %1").arg(root.timeAgo(notifItem.timestamp));
                    }
                    onCardClicked: {
                        notifItem.expanded = !notifItem.expanded;
                    }
                    onDismissed: root.notifications.dismissHistory(notifItem.notifId)
                    onActionInvoked: function(index) {
                        root.notifications.invokeAction(notifItem.notifId, index);
                    }
                }
            }
        }
    }
}
