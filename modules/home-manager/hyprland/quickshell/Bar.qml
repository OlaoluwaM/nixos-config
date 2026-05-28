pragma ComponentBehavior: Bound

import QtQuick

// Top bar content — all capsules laid out left-center-right.
// This Item fills the bar PanelWindow; the PanelWindow itself lives in shell.qml.
Item {
    id: root
    required property CaffeineActions caffeineActions
    required property ConnectivityActions connectivityActions
    required property MediaActions mediaActions
    required property StatusController status
    required property NotificationService notifications
    required property PopupController popups

    // ════════════════════════════════════════════════════════════════════
    //  LEFT: Workspace capsule
    // ════════════════════════════════════════════════════════════════════
    WorkspaceCapsule {
        id: workspaceCapsule
        anchors {
            left: parent.left
            leftMargin: 10
            verticalCenter: parent.verticalCenter
        }
    }

    // ════════════════════════════════════════════════════════════════════
    //  LEFT: Stats capsule (CPU / MEM / TEMP)
    // ════════════════════════════════════════════════════════════════════
    StatsCapsule {
        id: statsCapsule
        status: root.status
        anchors {
            left: workspaceCapsule.right
            leftMargin: 10
            verticalCenter: parent.verticalCenter
        }
    }

    // ════════════════════════════════════════════════════════════════════
    //  LEFT: Media capsule (visible only when playing/paused)
    // ════════════════════════════════════════════════════════════════════
    MediaCapsule {
        id: mediaCapsule
        mediaActions: root.mediaActions
        popups: root.popups
        status: root.status
        anchors {
            left: statsCapsule.right
            leftMargin: 10
            verticalCenter: parent.verticalCenter
        }
    }

    // ════════════════════════════════════════════════════════════════════
    //  CENTER: Clock + Notification capsules
    // ════════════════════════════════════════════════════════════════════
    Row {
        anchors.centerIn: parent
        spacing: 10

        ClockCapsule {
            id: clockPill
            popups: root.popups
            status: root.status
        }

        NotificationCapsule {
            id: notifCapsule
            popups: root.popups
            notifications: root.notifications
        }
    }

    // ════════════════════════════════════════════════════════════════════
    //  RIGHT: Tray, wifi, bluetooth, quick-settings capsules
    // ════════════════════════════════════════════════════════════════════
    Row {
        id: rightStatus
        spacing: 10
        anchors {
            right: parent.right
            rightMargin: 10
            verticalCenter: parent.verticalCenter
        }

        TrayCapsule {
            id: trayCapsule
            popups: root.popups
        }

        AirplaneModeCapsule {
            status: root.status
        }

        WifiCapsule {
            id: wifiCapsule
            connectivityActions: root.connectivityActions
            status: root.status
        }

        BluetoothCapsule {
            id: btCapsule
            connectivityActions: root.connectivityActions
            status: root.status
        }

        CaffeineCapsule {
            id: caffeineCapsule
            caffeineActions: root.caffeineActions
            status: root.status
        }

        QuickSettingsCapsule {
            id: quickSettingsCapsule
            popups: root.popups
        }
    }
}
