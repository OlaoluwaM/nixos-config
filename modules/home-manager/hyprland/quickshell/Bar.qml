pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

// Top bar content — all capsules laid out left-center-right.
// This Item fills the bar PanelWindow; the PanelWindow itself lives in shell.qml.
Item {
    id: bar
    required property var shell
    readonly property int statsSlotWidth: 54

    // ════════════════════════════════════════════════════════════════════
    //  LEFT: Workspace capsule
    // ════════════════════════════════════════════════════════════════════
    Rectangle {
        id: workspaceCapsule
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(36, workspaceRow.implicitWidth + 16)
        height: Theme.capsuleHeight
        radius: Theme.capsuleRadius
        color: Theme.surfaceVariant
        border.color: Theme.outline
        border.width: 1
        clip: true

        Behavior on width { NumberAnimation { duration: 200; easing.type: Theme.easingType; easing.bezierCurve: Theme.easingCurve } }

        Row {
            id: workspaceRow
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                id: wsRepeater
                model: Hyprland.workspaces

                delegate: Item {
                    id: wsDelegate
                    required property var modelData

                    property bool isActive: Hyprland.focusedMonitor !== null
                        && wsDelegate.modelData.id === Hyprland.focusedMonitor.activeWorkspace.id

                    width: 18
                    height: 18

                    Rectangle {
                        anchors.centerIn: parent
                        width: !wsDelegate.isActive && wsMouse.containsMouse ? 8 : 6
                        height: width
                        radius: width / 2
                        color: !wsDelegate.isActive && wsMouse.containsMouse ? Theme.tertiary : Theme.textSecondary
                        opacity: wsDelegate.isActive ? 0 : 1

                        Behavior on width { NumberAnimation { duration: 200; easing.type: Theme.easingType; easing.bezierCurve: Theme.easingCurve } }
                        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                        Behavior on opacity { OpacityAnimator { duration: 200 } }
                    }

                    MouseArea {
                        id: wsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: wsDelegate.modelData.activate()
                    }
                }
            }
        }

        Rectangle {
            id: wsHighlight

            property int activeIndex: {
                if (!Hyprland.focusedMonitor) return 0;
                let activeId = Hyprland.focusedMonitor.activeWorkspace.id;
                for (let i = 0; i < wsRepeater.count; i++) {
                    let item = wsRepeater.itemAt(i);
                    if (item && item.modelData.id === activeId) return i;
                }
                return 0;
            }

            visible: wsRepeater.count > 0
            width: 10
            height: 10
            radius: 5
            color: Theme.primary
            // Each item is 18px wide + 6px spacing = 24px stride; center 10px dot within 18px cell
            x: workspaceRow.x + activeIndex * 24 + 4
            y: workspaceRow.y + 4

            Behavior on x {
                id: wsHighlightAnim
                enabled: false
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.4
                }
            }

            Component.onCompleted: wsHighlightAnim.enabled = true
        }
    }

    // ════════════════════════════════════════════════════════════════════
    //  LEFT: Stats capsule (CPU / MEM / TEMP)
    // ════════════════════════════════════════════════════════════════════
    BarCapsule {
        id: statsCapsule
        anchors.left: workspaceCapsule.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 250
        respondToHover: false

        RowLayout {
            id: statsRow
            anchors.centerIn: parent
            spacing: 10

            Item {
                id: cpuStat
                Layout.preferredWidth: bar.statsSlotWidth
                Layout.preferredHeight: cpuStatContent.implicitHeight

                RowLayout {
                    id: cpuStatContent
                    anchors.centerIn: parent
                    spacing: 5

                    ShellIcon { name: "cpu"; iconColor: Theme.statsCpu; implicitSize: 16 }
                    Text {
                        text: bar.shell.cpuText
                        color: Theme.statsCpu
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignLeft

                        Layout.preferredWidth: 30
                    }
                }

                HoverHandler {
                    id: cpuHover
                }

                HoverTooltip {
                    active: cpuHover.hovered
                    text: qsTr("CPU: %1").arg(bar.shell.cpuText)
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: parent.bottom
                        topMargin: 8
                    }
                }
            }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 16; color: Theme.outline }

            Item {
                id: memoryStat
                Layout.preferredWidth: bar.statsSlotWidth
                Layout.preferredHeight: memoryStatContent.implicitHeight

                RowLayout {
                    id: memoryStatContent
                    anchors.centerIn: parent
                    spacing: 5

                    ShellIcon { name: "memory"; iconColor: Theme.statsMem; implicitSize: 16 }
                    Text {
                        text: bar.shell.memText
                        color: Theme.statsMem
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignLeft

                        Layout.preferredWidth: 30
                    }
                }

                HoverHandler {
                    id: memoryHover
                }

                HoverTooltip {
                    active: memoryHover.hovered
                    text: qsTr("Memory: %1").arg(bar.shell.memText)
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: parent.bottom
                        topMargin: 8
                    }
                }
            }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 16; color: Theme.outline }

            Item {
                id: tempStat
                Layout.preferredWidth: bar.statsSlotWidth
                Layout.preferredHeight: tempStatContent.implicitHeight

                RowLayout {
                    id: tempStatContent
                    anchors.centerIn: parent
                    spacing: 5

                    ShellIcon { name: "temp"; iconColor: Theme.statsTemp; implicitSize: 16 }
                    Text {
                        text: bar.shell.tempText
                        color: Theme.statsTemp
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignLeft

                        Layout.preferredWidth: 30
                    }
                }

                HoverHandler {
                    id: tempHover
                }

                HoverTooltip {
                    active: tempHover.hovered
                    text: qsTr("Temperature: %1").arg(bar.shell.tempText)
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: parent.bottom
                        topMargin: 8
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    //  LEFT: Media capsule (visible only when playing/paused)
    // ════════════════════════════════════════════════════════════════════
    BarCapsule {
        id: mediaCapsule
        anchors.left: statsCapsule.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        visible: bar.shell.mediaActive
        width: bar.shell.mediaActive ? 280 : 0
        active: bar.shell.activePopup === "media"
        clipped: true

        Row {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            // Album art thumbnail
            Rectangle {
                width: 30
                height: Theme.capsuleButtonSize
                radius: Theme.capsuleButtonRadius
                color: Theme.outline
                clip: true

                Image {
                    id: mediaArtwork
                    anchors.fill: parent
                    source: bar.shell.mediaAlbumArt
                    sourceSize.width: 30
                    sourceSize.height: 30
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: bar.shell.mediaAlbumArt !== "" && mediaArtwork.status === Image.Ready
                }

                ShellIcon {
                    anchors.centerIn: parent
                    visible: bar.shell.mediaAlbumArt === "" || mediaArtwork.status !== Image.Ready
                    name: bar.shell.mediaStatus === "Playing" ? "play" : "music"
                    iconColor: Theme.text
                    implicitSize: 16
                }
            }

            // Title + position
            Item {
                width: 132
                height: 30

                Column {
                    anchors.fill: parent
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    MarqueeText {
                        width: parent.width
                        height: implicitHeight
                        text: bar.shell.mediaDisplayTitle
                        color: Theme.capsuleTextColor(bar.shell.activePopup === "media", mediaCapsule.hovered)
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    Text {
                        width: parent.width
                        text: bar.shell.mediaPosition + " / " + bar.shell.mediaLength
                        color: Theme.capsuleTextColor(bar.shell.activePopup === "media", mediaCapsule.hovered)
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        textFormat: Text.PlainText
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: bar.shell.togglePopup("media")
                }
            }

            // Playback controls
            Row {
                width: 74
                height: 30
                spacing: 4

                Repeater {
                    model: [
                        { action: "previous",   icon: "previous" },
                        { action: "play-pause",  icon: bar.shell.mediaStatus === "Playing" ? "pause" : "play" },
                        { action: "next",        icon: "next" }
                    ]

                    delegate: IconButton {
                        required property var modelData

                        accessibleName: modelData.action
                        buttonWidth: 22
                        buttonHeight: Theme.capsuleButtonSize
                        width: implicitWidth
                        height: implicitHeight
                        iconName: modelData.icon
                        iconSize: 15
                        iconColor: hovered ? Theme.tertiaryContrast
                            : Theme.capsuleTextColor(bar.shell.activePopup === "media", mediaCapsule.hovered)
                        normalColor: "transparent"
                        onClicked: bar.shell.runPlayerctl(modelData.action)
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    //  CENTER: Clock + Notification capsules
    // ════════════════════════════════════════════════════════════════════
    Row {
        anchors.centerIn: parent
        spacing: 10

        // ── Clock capsule ─────────────────────────────────────────────
        BarCapsule {
            id: clockPill
            width: clockRow.implicitWidth + 30
            active: bar.shell.activePopup === "calendar"

            Row {
                id: clockRow
                anchors.centerIn: parent
                spacing: 10

                Text {
                    text: {
                        let parts = bar.shell.clockText.split(" ");
                        return parts.slice(0, 2).join(" ");
                    }
                    color: Theme.capsuleTextColor(bar.shell.activePopup === "calendar", clockPill.hovered)
                    font.pixelSize: 14
                    font.weight: Font.DemiBold

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                Text {
                    text: {
                        let parts = bar.shell.clockText.split(" ");
                        return parts.slice(2).join(" ");
                    }
                    color: Theme.capsuleTextColor(bar.shell.activePopup === "calendar", clockPill.hovered)
                    font.pixelSize: 14
                    font.weight: Font.DemiBold

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
            }

            MouseArea {
                id: clockMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: bar.shell.togglePopup("calendar")
            }
        }

        // ── Notification capsule ──────────────────────────────────────
        BarCapsule {
            id: notifCapsule
            width: Theme.capsuleHeight
            active: bar.shell.activePopup === "notifications"

            ShellIcon {
                id: notifBellIcon
                anchors.centerIn: parent
                name: bar.shell.doNotDisturb ? "notificationsOff" : "notifications"
                iconColor: Theme.capsuleTextColor(bar.shell.activePopup === "notifications", notifCapsule.hovered)
                implicitSize: 15
            }

            Rectangle {
                visible: bar.shell.notificationHistoryModel.count > 0
                width: 7
                height: 7
                radius: 3.5
                color: Theme.error
                anchors.left: notifBellIcon.right
                anchors.top: notifBellIcon.top
                anchors.leftMargin: -2
                anchors.topMargin: -3
            }

            MouseArea {
                id: notifMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: bar.shell.togglePopup("notifications")
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    //  RIGHT: Tray, wifi, bluetooth, quick-settings capsules
    // ════════════════════════════════════════════════════════════════════
    Row {
        id: rightStatus
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        // ── Tray capsule (hidden when empty) ───────────────────────────
        BarCapsule {
            id: trayCapsule
            visible: bar.shell.trayItemCount > 0
            width: bar.shell.trayItemCount > 0 ? Theme.capsuleHeight : 0
            active: bar.shell.activePopup === "tray"

            ShellIcon {
                anchors.centerIn: parent
                name: "tray"
                iconColor: Theme.capsuleTextColor(bar.shell.activePopup === "tray", trayCapsule.hovered)
                implicitSize: 16
            }

            MouseArea {
                id: trayBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: bar.shell.togglePopup("tray")
            }
        }

        // ── Airplane mode capsule (visible when active) ────────────────
        Rectangle {
            visible: bar.shell.airplaneMode
            width: bar.shell.airplaneMode ? Theme.capsuleHeight : 0
            height: Theme.capsuleHeight
            radius: Theme.capsuleRadius
            color: Theme.primary
            border.color: Theme.primary
            border.width: 1

            ShellIcon {
                anchors.centerIn: parent
                name: "airplane"
                iconColor: Theme.primaryContrast
                implicitSize: 15
            }
        }

        // ── Wifi capsule ──────────────────────────────────────────────
        BarCapsule {
            id: wifiCapsule
            width: Math.max(Theme.capsuleHeight, wifiContent.implicitWidth + 20)
            opacity: bar.shell.airplaneMode ? 0.35 : 1.0

            Behavior on opacity     { OpacityAnimator { duration: Theme.animNormal } }

            RowLayout {
                id: wifiContent
                anchors.centerIn: parent
                spacing: 5

                ShellIcon {
                    name: bar.shell.airplaneMode || bar.shell.networkText === "Offline" ? "networkOff" : "network"
                    iconColor: Theme.capsuleTextColor(false, wifiCapsule.hovered)
                    implicitSize: 15
                }

                MarqueeText {
                    Layout.alignment: Qt.AlignVCenter
                    visible: !bar.shell.airplaneMode && bar.shell.networkText !== "Offline"
                    text: bar.shell.networkText
                    color: Theme.capsuleTextColor(false, wifiCapsule.hovered)
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    Layout.maximumWidth: 120
                    Layout.preferredWidth: Math.min(implicitWidth, 120)
                    Layout.preferredHeight: implicitHeight
                }
            }

            MouseArea {
                id: wifiMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: bar.shell.runNetworkCommand()
            }
        }

        // ── Bluetooth capsule ─────────────────────────────────────────
        BarCapsule {
            id: btCapsule
            width: Math.max(Theme.capsuleHeight, btContent.implicitWidth + 20)
            opacity: bar.shell.airplaneMode ? 0.35 : 1.0

            Behavior on opacity     { OpacityAnimator { duration: Theme.animNormal } }

            RowLayout {
                id: btContent
                anchors.centerIn: parent
                spacing: 5

                ShellIcon {
                    name: "bluetooth"
                    iconColor: Theme.capsuleTextColor(false, btCapsule.hovered)
                    implicitSize: 15
                }

                MarqueeText {
                    Layout.alignment: Qt.AlignVCenter
                    visible: !bar.shell.airplaneMode && bar.shell.bluetoothDevice !== ""
                    text: bar.shell.bluetoothDevice
                    color: Theme.capsuleTextColor(false, btCapsule.hovered)
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    Layout.maximumWidth: 120
                    Layout.preferredWidth: Math.min(implicitWidth, 120)
                    Layout.preferredHeight: implicitHeight
                }
            }

            MouseArea {
                id: btMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: bar.shell.runBluetoothCommand()
            }
        }

        // ── Quick settings capsule ─────────────────────────────────────
        BarCapsule {
            id: quickSettingsCapsule
            width: Theme.capsuleHeight
            active: bar.shell.activePopup === "quickSettings"

            ShellIcon {
                anchors.centerIn: parent
                name: "quick"
                iconColor: Theme.capsuleTextColor(bar.shell.activePopup === "quickSettings", quickSettingsCapsule.hovered)
                implicitSize: 17
            }

            MouseArea {
                id: qsMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: bar.shell.togglePopup("quickSettings")
            }
        }
    }
}
