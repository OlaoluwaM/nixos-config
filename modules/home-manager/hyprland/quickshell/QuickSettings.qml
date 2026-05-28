pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: quickSettings
    required property var shell
    required property var status
    required property var notifications
    spacing: 18

    property int batteryPercent: parseInt(status.batteryText) || 0
    property bool isCharging: {
        let t = status.batteryText.toLowerCase();
        return t.indexOf("charging") >= 0
            && t.indexOf("not charging") < 0
            && t.indexOf("discharging") < 0;
    }
    property bool showPowerMenu: false
    property string normalizedPowerProfile: {
        let p = status.powerProfileText.toLowerCase();
        if (p === "saver" || p === "quiet") return "power-saver";
        return p;
    }

    property string batteryStatusLabel: {
        let t = status.batteryText.toLowerCase();
        if (t === "ac") return "AC Power";
        if (isCharging) return "Charging";
        if (t.indexOf("not charging") >= 0) return "Plugged In";
        if (t.indexOf("full") >= 0) return "Full";
        if (t.indexOf("discharging") >= 0) return "On Battery";
        return "On Battery";
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

                Text {
                    id: bigPct
                    text: quickSettings.batteryPercent.toString()
                    color: Theme.text
                    font.pixelSize: 54
                    font.weight: Font.DemiBold
                }

                Text {
                    id: pctSign
                    text: "%"
                    color: Theme.textSecondary
                    font.pixelSize: 22
                    anchors.left: bigPct.right
                    anchors.baseline: bigPct.baseline
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                ShellIcon {
                    name: quickSettings.isCharging ? "batteryCharging" : "battery"
                    iconColor: Theme.textSecondary
                    implicitSize: 12
                }

                Text {
                    text: quickSettings.batteryStatusLabel
                    color: Theme.textSecondary
                    font.pixelSize: 13
                }
            }
        }
    }

    // ── Brightness slider ────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ShellIcon {
            name: brightnessSlider.value <= 1 ? "brightnessOff" : "brightness"
            iconColor: brightnessSlider.value <= 1 ? Theme.textDim : Theme.textSecondary
            implicitSize: 16
        }

        StyledSlider {
            id: brightnessSlider
            Layout.fillWidth: true
            from: 1; to: 100
            value: Number(quickSettings.status.brightnessText.replace("%", "")) || 50
            accentColor: Theme.primary
            onMoved: quickSettings.shell.setBrightness(value)
        }
    }

    // ── Volume slider ────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ShellIcon {
            name: quickSettings.status.muted || volumeSlider.value <= 0 ? "volumeMuted" : "volume"
            iconColor: quickSettings.status.muted || volumeSlider.value <= 0 ? Theme.textDim : Theme.textSecondary
            implicitSize: 16
        }

        StyledSlider {
            id: volumeSlider
            Layout.fillWidth: true
            from: 0; to: 100
            value: Number(quickSettings.status.volumeText.replace("%", "")) || 0
            accentColor: Theme.primary
            onMoved: quickSettings.shell.setVolume(value)
        }
    }

    // ── Quick toggles ────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Repeater {
            model: [
                { icon: "lock",             activeIcon: "lock",             action: "lock",     danger: false, toggle: false },
                { icon: "notifications",    activeIcon: "notificationsOff", action: "dnd",      danger: false, toggle: true  },
                { icon: "airplane",         activeIcon: "airplane",         action: "airplane", danger: false, toggle: true  },
                { icon: "power",            activeIcon: "power",            action: "power",    danger: true,  toggle: false }
            ]

            delegate: IconButton {
                id: toggleBtn
                required property var modelData

                active: (modelData.action === "dnd" && quickSettings.notifications.doNotDisturb)
                    || (modelData.action === "airplane" && quickSettings.status.airplaneMode)
                    || (modelData.action === "power" && quickSettings.showPowerMenu)
                activeColor: modelData.danger ? Theme.error : Theme.primary
                accessibleName: modelData.action
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
                        case "lock": quickSettings.shell.runLockCommand(); break;
                        case "dnd": quickSettings.notifications.toggleDoNotDisturb(); break;
                        case "airplane": quickSettings.shell.toggleAirplaneMode(); break;
                        case "power": quickSettings.showPowerMenu = !quickSettings.showPowerMenu; break;
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
                            quickSettings.shell.requestConfirmation(
                                qsTr("Log Out"), qsTr("Your session will end."),
                                "logout", false, 60, "logout");
                            break;
                        case "reboot":
                            quickSettings.shell.requestConfirmation(
                                qsTr("Restart"), qsTr("The system will restart."),
                                "refresh", false, 60, "reboot");
                            break;
                        case "suspend":
                            quickSettings.shell.requestConfirmation(
                                qsTr("Suspend"), qsTr("The system will go to sleep."),
                                "sleep", false, 60, "suspend");
                            break;
                        case "poweroff":
                            quickSettings.shell.requestConfirmation(
                                qsTr("Power Off"), qsTr("The system will shut down."),
                                "power", true, 60, "poweroff");
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

                active: quickSettings.normalizedPowerProfile === modelData.value
                activeColor: Theme.primary
                accessibleName: modelData.label
                bordered: true
                buttonSize: 42
                iconName: modelData.icon
                iconSize: 15
                normalColor: "transparent"

                Layout.fillWidth: true
                Layout.preferredHeight: 42

                onClicked: quickSettings.shell.runPowerProfileSet(profileBtn.modelData.value)

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
