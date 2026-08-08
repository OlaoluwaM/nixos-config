pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property NotificationService notifications
    property bool heightAnimationsReady: false
    property bool _tick: false

    spacing: Theme.popoverSectionGap

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

        StyledText {
            text: qsTr("Notifications")
            color: Theme.text
            font.pixelSize: Theme.fontHeader
            font.weight: Font.DemiBold
            Layout.alignment: Qt.AlignBaseline
        }

        StyledText {
            text: root.notifications.historyModel.count
            color: Theme.textDim
            font.pixelSize: Theme.fontBody
            visible: root.notifications.historyModel.count > 0
            Layout.alignment: Qt.AlignBaseline
        }

        Item { Layout.fillWidth: true }

        StyledText {
            text: qsTr("Clear")
            color: clearMouse.containsMouse ? Theme.text : Theme.textSecondary
            font.pixelSize: Theme.fontBody
            visible: root.notifications.historyModel.count > 0
            Layout.alignment: Qt.AlignBaseline

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingType; easing.bezierCurve: Theme.easingCurve } }

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
            spacing: Theme.popoverContentGap

            ShellIcon {
                name: "notifications"
                iconColor: Theme.textDim
                implicitSize: 28
                Layout.alignment: Qt.AlignHCenter
            }

            StyledText {
                text: qsTr("All clear")
                color: Theme.textDim
                font.pixelSize: Theme.fontMedium
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
            spacing: Theme.popoverContentGap

            Repeater {
                model: root.notifications.historyModel

                delegate: NotificationCard {
                    id: notifItem
                    required property real timestamp

                    width: notifColumn.width
                    radius: Theme.cardRadius
                    expandable: true
                    heightAnimationEnabled: root.heightAnimationsReady
                    backgroundColor: Theme.surfaceVariant
                    dismissHoverColor: Theme.surfaceHover
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
