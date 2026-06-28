pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: quickSettings
    required property AudioActions audioActions
    required property BrightnessActions brightnessActions
    required property ConnectivityActions connectivityActions
    required property PowerActions powerActions
    required property StatusController status
    required property NotificationService notifications

    property int batteryPercent: status.batteryPercent
    property bool showPowerMenu: false
    readonly property color batteryStateColor: quickSettings.batteryColor(quickSettings.status.batteryVisualState)
    readonly property string currentPowerProfile: status.powerProfile

    property string batteryStatusLabel: status.batteryStatusLabel
    spacing: 18

    function batteryColor(state) {
        if (state === "success") return Theme.success;
        if (state === "error") return Theme.error;
        if (state === "warning") return Theme.warning;
        return Theme.textSecondary;
    }

    // ── Battery display ──────────────────────────────────────────────
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: bigPct.implicitWidth + pctSign.implicitWidth
                implicitHeight: bigPct.implicitHeight

                StyledText {
                    id: bigPct
                    text: quickSettings.batteryPercent.toString()
                    color: Theme.text
                    font.pixelSize: Theme.fontDisplay
                    font.weight: Font.DemiBold
                }

                StyledText {
                    id: pctSign
                    text: "%"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontTitle
                    anchors.left: bigPct.right
                    anchors.baseline: bigPct.baseline
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                ShellIcon {
                    id: batteryIcon

                    name: quickSettings.status.batteryIconName
                    iconColor: quickSettings.batteryStateColor
                    implicitSize: 18
                    opacity: 1.0

                    SequentialAnimation on opacity {
                        running: quickSettings.status.batteryVisualState === "error"
                        loops: Animation.Infinite
                        onStopped: batteryIcon.opacity = 1.0

                        OpacityAnimator { to: 0.35; duration: 550; easing.type: Theme.easingType; easing.bezierCurve: Theme.easingCurve }
                        OpacityAnimator { to: 1.0; duration: 550; easing.type: Theme.easingType; easing.bezierCurve: Theme.easingCurve }
                    }
                }

                StyledText {
                    text: quickSettings.batteryStatusLabel
                    color: quickSettings.batteryStateColor
                    font.pixelSize: Theme.fontBody
                }
            }
        }
    }

    // ── Brightness slider ────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ShellIcon {
            name: Icons.brightnessName(brightnessSlider.value)
            iconColor: brightnessSlider.value <= 1 ? Theme.textDim : Theme.textSecondary
            implicitSize: 16
        }

        StyledSlider {
            id: brightnessSlider
            Layout.fillWidth: true
            from: 1; to: 100
            // brightnessPercent is null when there is no backlight (e.g. VMs);
            // fall back to empty rather than a fabricated mid-range reading.
            externalValue: quickSettings.status.brightnessPercent !== null ? quickSettings.status.brightnessPercent : 0
            accentColor: Theme.primary
            onMoved: quickSettings.brightnessActions.setBrightness(value)
        }
    }

    // ── Volume slider ────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ShellIcon {
            name: Icons.volumeName(quickSettings.status.muted, volumeSlider.value)
            iconColor: quickSettings.status.muted || volumeSlider.value <= 0 ? Theme.textDim : Theme.textSecondary
            implicitSize: 16
        }

        StyledSlider {
            id: volumeSlider
            Layout.fillWidth: true
            from: 0; to: 100
            // Use the numeric facade alias, not the presentation string — parsing
            // volumeText breaks on the "N/A" (no-audio) case, coercing it to 0.
            externalValue: quickSettings.status.volumePercent
            accentColor: Theme.primary
            onMoved: quickSettings.audioActions.setVolume(value)
        }
    }

    // ── Quick toggles ────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Repeater {
            model: [
                { label: qsTr("Lock"),              icon: "lock",             activeIcon: "lock",             action: "lock",     danger: false, toggle: false },
                { label: qsTr("Do Not Disturb"),    icon: "notifications",    activeIcon: "notificationsOff", action: "dnd",      danger: false, toggle: true  },
                // activeIcon swaps to the slashed glyph when engaged, matching the
                // dnd toggle above (engaged → "off" glyph = radios suppressed).
                { label: qsTr("Airplane Mode"),     icon: "airplane",         activeIcon: "airplaneOff",      action: "airplane", danger: false, toggle: true  },
                { label: qsTr("Power Menu"),        icon: "power",            activeIcon: "power",            action: "power",    danger: true,  toggle: false }
            ]

            delegate: IconButton {
                id: toggleBtn
                required property var modelData

                active: (modelData.action === "dnd" && quickSettings.notifications.doNotDisturb)
                    || (modelData.action === "airplane" && quickSettings.status.airplaneMode)
                    || (modelData.action === "power" && quickSettings.showPowerMenu)
                activeColor: modelData.danger ? Theme.error : Theme.primary
                accessibleName: modelData.label
                bordered: true
                buttonSize: 42
                danger: modelData.danger
                iconName: toggleBtn.active ? modelData.activeIcon : modelData.icon
                iconSize: 15
                normalColor: "transparent"

                Layout.fillWidth: true
                Layout.preferredHeight: 42

                onClicked: {
                    switch (toggleBtn.modelData.action) {
                        case "lock": quickSettings.powerActions.runLockCommand(); break;
                        case "dnd": quickSettings.notifications.toggleDoNotDisturb(); break;
                        case "airplane": quickSettings.connectivityActions.toggleAirplaneMode(); break;
                        case "power": quickSettings.showPowerMenu = !quickSettings.showPowerMenu; break;
                    }
                }

                HoverTooltip {
                    active: toggleBtn.hovered
                    text: toggleBtn.modelData.label
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.top
                        bottomMargin: 6
                    }
                }
            }
        }
    }

    // ── Power menu (replaces profile pills when active) ─────────────
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 42
        spacing: 10
        visible: quickSettings.showPowerMenu

        Repeater {
            model: [
                { label: qsTr("Log Out"),   icon: "logout",  action: "logout" },
                { label: qsTr("Reboot"),    icon: "refresh", action: "reboot" },
                { label: qsTr("Suspend"),   icon: "sleep",   action: "suspend" },
                { label: qsTr("Power Off"), icon: "power",   action: "poweroff" }
            ]

            delegate: IconButton {
                id: powerBtn
                required property var modelData

                property bool isDanger: modelData.action === "poweroff"

                accessibleName: modelData.label
                bordered: true
                buttonSize: 42
                danger: powerBtn.isDanger
                iconName: modelData.icon
                iconSize: 15
                normalColor: "transparent"

                Layout.fillWidth: true
                Layout.preferredHeight: 42

                onClicked: {
                    switch (powerBtn.modelData.action) {
                        case "logout":
                            quickSettings.powerActions.requestLogout();
                            break;
                        case "reboot":
                            quickSettings.powerActions.requestReboot();
                            break;
                        case "suspend":
                            quickSettings.powerActions.requestSuspend();
                            break;
                        case "poweroff":
                            quickSettings.powerActions.requestPowerOff();
                            break;
                    }
                }

                HoverTooltip {
                    active: powerBtn.hovered
                    text: powerBtn.modelData.label
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.top
                        bottomMargin: 6
                    }
                }
            }
        }
    }

    // ── Power profile buttons ────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 42
        spacing: 10
        visible: !quickSettings.showPowerMenu

        Repeater {
            model: [
                { label: qsTr("Performance"), value: "performance", icon: "bolt"  },
                { label: qsTr("Balanced"),    value: "balanced",    icon: "gauge" },
                { label: qsTr("Power Saver"), value: "power-saver", icon: "leaf"  }
            ]

            delegate: IconButton {
                id: profileBtn
                required property var modelData

                active: quickSettings.currentPowerProfile === modelData.value
                activeColor: Theme.primary
                accessibleName: modelData.label
                bordered: true
                buttonSize: 42
                iconName: modelData.icon
                iconSize: 15
                normalColor: "transparent"

                Layout.fillWidth: true
                Layout.preferredHeight: 42

                onClicked: quickSettings.powerActions.runPowerProfileSet(profileBtn.modelData.value)

                HoverTooltip {
                    active: profileBtn.hovered
                    text: profileBtn.modelData.label
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.top
                        bottomMargin: 6
                    }
                }
            }
        }
    }
}
