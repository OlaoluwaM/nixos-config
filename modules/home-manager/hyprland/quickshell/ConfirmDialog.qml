pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: confirmWindow
    required property var shell

    color: "transparent"
    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-confirm"

    visible: shell.confirmDialogVisible
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    QtObject {
        id: countdown
        property int remaining: 0
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            countdown.remaining -= 1;
            if (countdown.remaining <= 0) {
                stop();
                confirmWindow.executeAction();
            }
        }
    }

    function executeAction() {
        let action = shell.confirmAction;
        shell.dismissConfirmDialog();
        switch (action) {
            case "logout": shell.runLogoutCommand(); break;
            case "reboot": shell.runRebootCommand(); break;
            case "suspend": shell.runSleepCommand(); break;
            case "poweroff": shell.runPowerOffCommand(); break;
        }
    }

    Connections {
        target: confirmWindow.shell
        function onConfirmDialogVisibleChanged() {
            if (confirmWindow.shell.confirmDialogVisible) {
                countdown.remaining = confirmWindow.shell.confirmTimeout;
                confirmCard.opacity = 0;
                confirmCard.scale = 0.92;
                openAnim.start();
                if (confirmWindow.shell.confirmTimeout > 0)
                    countdownTimer.start();
            } else {
                countdownTimer.stop();
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: confirmCard.opacity * 0.4
    }

    Rectangle {
        id: confirmCard
        anchors.centerIn: parent
        width: 360
        height: contentCol.implicitHeight + 64
        radius: Theme.popoverRadius
        color: Theme.base
        border.color: Theme.outline
        border.width: 1

        transformOrigin: Item.Center
        opacity: 0
        scale: 0.92

        MouseArea { anchors.fill: parent }

        ParallelAnimation {
            id: openAnim
            NumberAnimation {
                target: confirmCard; property: "opacity"
                from: 0; to: 1
                duration: Theme.animFade
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: confirmCard; property: "scale"
                from: 0.92; to: 1.0
                duration: Theme.animNormal
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            id: contentCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 32
            }
            spacing: 16

            ShellIcon {
                Layout.alignment: Qt.AlignHCenter
                name: confirmWindow.shell.confirmIcon
                iconColor: confirmWindow.shell.confirmDanger ? Theme.error : Theme.text
                implicitSize: 28
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: confirmWindow.shell.confirmTitle
                color: Theme.text
                font.pixelSize: 22
                font.weight: Font.DemiBold
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: contentCol.width
                text: confirmWindow.shell.confirmDescription
                color: Theme.textSecondary
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            ColumnLayout {
                visible: confirmWindow.shell.confirmTimeout > 0
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4
                    radius: 2
                    color: Theme.surfaceVariant

                    Rectangle {
                        height: parent.height
                        radius: 2
                        color: confirmWindow.shell.confirmDanger ? Theme.error : Theme.primary
                        opacity: 0.7
                        width: confirmWindow.shell.confirmTimeout > 0
                            ? parent.width * (countdown.remaining / confirmWindow.shell.confirmTimeout)
                            : 0

                        Behavior on width {
                            NumberAnimation {
                                duration: 1000
                                easing.type: Easing.Linear
                            }
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Confirming in %1s").arg(countdown.remaining)
                    color: Theme.textDim
                    font.pixelSize: 12
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 10

                ActionButton {
                    Layout.fillWidth: true
                    label: qsTr("Cancel")
                    filled: false
                    buttonHeight: 38
                    onClicked: confirmWindow.shell.dismissConfirmDialog()
                }

                ActionButton {
                    Layout.fillWidth: true
                    label: confirmWindow.shell.confirmTitle
                    filled: true
                    danger: confirmWindow.shell.confirmDanger
                    accentColor: confirmWindow.shell.confirmDanger ? Theme.error : Theme.primary
                    buttonHeight: 38
                    onClicked: confirmWindow.executeAction()
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: confirmWindow.shell.dismissConfirmDialog()
    }
}
