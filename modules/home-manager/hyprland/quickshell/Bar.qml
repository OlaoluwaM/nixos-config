pragma ComponentBehavior: Bound

import QtQuick

// Top-bar rail. The three groups stay independently anchored so changing media
// or tray content never shifts the clock away from the screen centre.
Rectangle {
    id: root
    required property CaffeineActions caffeineActions
    required property ConnectivityActions connectivityActions
    required property MediaActions mediaActions
    required property StatusController status
    required property NotificationService notifications
    required property PopupController popups

    // Responsive priority policy. The stable desired widths make the fit checks
    // monotonic: media drops first, then stats, then connectivity labels. The
    // date is the final informational detail to collapse; every trigger remains.
    readonly property int visibleRightControlCount: 4
        + (trayCapsule.visible ? 1 : 0)
        + (airplaneModeCapsule.visible ? 1 : 0)
    readonly property real leftCoreWidth: Theme.barGroupPadding * 2 + workspaceCapsule.width
    readonly property real leftWithStatsWidth: root.leftCoreWidth
        + Theme.barGroupGap + statsCapsule.width
    readonly property real leftExpandedWidth: root.leftWithStatsWidth
        + (root.status.mediaActive ? Theme.barGroupGap + mediaCapsule.width : 0)
    readonly property real rightCompactWidth: Theme.barGroupPadding * 2
        + trayCapsule.width + airplaneModeCapsule.width
        + Theme.barControlHeight * 4
        + Theme.barGroupGap * Math.max(0, root.visibleRightControlCount - 1)
    readonly property real rightExpandedWidth: root.rightCompactWidth
        - Theme.barControlHeight * 2
        + networkCapsule.expandedWidth + bluetoothCapsule.expandedWidth
    readonly property real fullCenterWidth: Theme.barGroupPadding * 2
        + clockCapsule.expandedWidth + Theme.barGroupGap + notificationCapsule.width
    readonly property real availableSectionWidth: root.width - Theme.barPadding * 2
        - Theme.barSectionGap * 2
    readonly property bool compactClock: root.leftCoreWidth + root.fullCenterWidth
        + root.rightCompactWidth > root.availableSectionWidth
    readonly property real preferredCenterX: (root.width - centerGroup.width) / 2
    readonly property bool showStats: root.leftWithStatsWidth + root.fullCenterWidth
        + root.rightExpandedWidth <= root.availableSectionWidth
    readonly property bool showMedia: root.showStats && root.status.mediaActive
        && root.leftExpandedWidth + root.fullCenterWidth
            + root.rightExpandedWidth <= root.availableSectionWidth
    readonly property bool showConnectivityLabels: root.leftCoreWidth
        + root.fullCenterWidth + root.rightExpandedWidth <= root.availableSectionWidth

    radius: Theme.barRailRadius
    color: Theme.barRailColor

    BarGroup {
        id: leftGroup
        width: leftContent.implicitWidth + Theme.barGroupPadding * 2
        anchors {
            left: parent.left
            leftMargin: Theme.barPadding
            verticalCenter: parent.verticalCenter
        }

        Row {
            id: leftContent
            anchors.centerIn: parent
            spacing: Theme.barGroupGap

            WorkspaceCapsule { id: workspaceCapsule }

            StatsCapsule {
                id: statsCapsule
                visible: root.showStats
                status: root.status
            }

            MediaCapsule {
                id: mediaCapsule
                visible: root.showMedia
                mediaActions: root.mediaActions
                popups: root.popups
                status: root.status
            }
        }
    }

    BarGroup {
        id: centerGroup
        width: centerContent.implicitWidth + Theme.barGroupPadding * 2
        x: Math.max(leftGroup.x + leftGroup.width + Theme.barSectionGap,
            Math.min(root.preferredCenterX,
                rightGroup.x - centerGroup.width - Theme.barSectionGap))
        anchors.verticalCenter: parent.verticalCenter

        Row {
            id: centerContent
            anchors.centerIn: parent
            spacing: Theme.barGroupGap

            ClockCapsule {
                id: clockCapsule
                compact: root.compactClock
                popups: root.popups
                status: root.status
            }

            NotificationCapsule {
                id: notificationCapsule
                popups: root.popups
                notifications: root.notifications
            }
        }
    }

    BarGroup {
        id: rightGroup
        width: rightContent.implicitWidth + Theme.barGroupPadding * 2
        anchors {
            right: parent.right
            rightMargin: Theme.barPadding
            verticalCenter: parent.verticalCenter
        }

        Row {
            id: rightContent
            anchors.centerIn: parent
            spacing: Theme.barGroupGap

            TrayCapsule {
                id: trayCapsule
                popups: root.popups
            }
            AirplaneModeCapsule {
                id: airplaneModeCapsule
                status: root.status
            }
            NetworkCapsule {
                id: networkCapsule
                showLabel: root.showConnectivityLabels
                connectivityActions: root.connectivityActions
                status: root.status
            }
            BluetoothCapsule {
                id: bluetoothCapsule
                showLabel: root.showConnectivityLabels
                connectivityActions: root.connectivityActions
                status: root.status
            }
            CaffeineCapsule {
                caffeineActions: root.caffeineActions
                status: root.status
            }
            QuickSettingsCapsule { popups: root.popups }
        }
    }
}
