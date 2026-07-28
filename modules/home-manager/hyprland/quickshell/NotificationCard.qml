pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    required property int notifId
    required property string appName
    required property string summary
    required property string body
    required property bool hasActions
    required property string actionsJson
    required property int defaultActionIndex
    required property int urgency

    property bool expanded: false
    property bool expandable: false
    property bool contentCentered: false
    property bool dismissAlwaysVisible: false
    property bool heightAnimationEnabled: false
    property int minimumCardHeight: 104
    property int verticalPadding: 17
    property string timeText: qsTr("· now")
    property color dismissHoverColor: Theme.base
    property color backgroundColor: Theme.surfaceVariant
    property color strokeColor: "transparent"
    property int strokeWidth: 0

    readonly property color urgencyColor: root.urgency === 2 ? Theme.error
        : root.urgency === 0 ? Theme.secondary
        : Theme.primary

    signal dismissed()
    signal actionInvoked(int index)
    signal cardClicked()

    height: Math.max(root.minimumCardHeight, cardContent.implicitHeight + root.verticalPadding * 2)
    radius: Theme.cardRadius
    topLeftRadius: 0
    bottomLeftRadius: 0
    color: root.backgroundColor
    border.color: root.strokeColor
    border.width: root.strokeWidth
    clip: true

    Behavior on height {
        enabled: root.heightAnimationEnabled
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Theme.easingType
            easing.bezierCurve: Theme.easingCurve
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (root.expandable) {
                root.cardClicked();
            } else if (root.defaultActionIndex >= 0) {
                // Freedesktop convention: the "default" action is invoked by
                // activating the notification itself, never shown as a button.
                // Expandable (history) cards keep click-to-expand instead.
                root.actionInvoked(root.defaultActionIndex);
            }
        }
    }

    HoverHandler {
        id: cardHover
    }

    Rectangle {
        width: 4
        color: root.urgencyColor
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
    }

    ColumnLayout {
        id: cardContent
        x: 20
        y: root.contentCentered
            ? Math.round((root.height - cardContent.implicitHeight) / 2)
            : root.verticalPadding
        width: root.width - 34
        spacing: 4

        RowLayout {
            spacing: 6
            Layout.fillWidth: true

            StyledText {
                text: root.appName
                color: Theme.textSecondary
                font.pixelSize: Theme.fontCaption
                font.weight: Font.Normal
            }

            StyledText {
                text: root.timeText
                color: Theme.textDim
                font.pixelSize: Theme.fontCaption
            }

            Item { Layout.fillWidth: true }

            Item {
                opacity: root.dismissAlwaysVisible || cardHover.hovered || dismissMouse.containsMouse ? 1 : 0
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26

                Behavior on opacity { OpacityAnimator { duration: Theme.animFast; easing.type: Theme.easingType; easing.bezierCurve: Theme.easingCurve } }

                Rectangle {
                    anchors.fill: parent
                    visible: dismissMouse.containsMouse
                    color: root.dismissHoverColor
                    radius: Theme.capsuleButtonRadius
                }

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
                    onClicked: root.dismissed()
                }
            }
        }

        StyledText {
            text: root.summary
            color: Theme.text
            font.pixelSize: 15
            font.weight: Font.DemiBold
            wrapMode: root.expandable && !root.expanded ? Text.NoWrap : Text.Wrap
            elide: root.expandable && !root.expanded ? Text.ElideRight : Text.ElideNone
            textFormat: Text.PlainText
            Layout.fillWidth: true
            // Extra breathing room below the app/time header row; the column
            // spacing (4) is kept tight for the title↔body gap.
            Layout.topMargin: 6
        }

        StyledText {
            text: root.body
            color: Theme.textSecondary
            font.pixelSize: Theme.fontMedium
            font.weight: Font.Normal
            wrapMode: Text.Wrap
            maximumLineCount: root.expandable && !root.expanded ? 2 : 100
            elide: root.expandable && !root.expanded ? Text.ElideRight : Text.ElideNone
            textFormat: Text.PlainText
            visible: text.length > 0
            Layout.fillWidth: true
        }

        NotificationActionRow {
            hasActions: root.hasActions
            actionsJson: root.actionsJson
            urgency: root.urgency
            Layout.fillWidth: true
            Layout.topMargin: 16
            onActionInvoked: function(index) {
                root.actionInvoked(index);
            }
        }
    }
}
