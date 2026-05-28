pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: confirmWindow

    property bool dialogVisible: false
    property string dialogTitle: ""
    property string dialogDescription: ""
    property string dialogIcon: ""
    property bool dialogDanger: false
    property int dialogTimeout: 0
    property string dialogAction: ""
    readonly property color cancelButtonColor: "#2b2d33"
    readonly property color cancelButtonHoverColor: "#363941"
    readonly property color cancelButtonBorderColor: "#474b55"
    readonly property color cancelButtonHoverBorderColor: "#5a5f6b"
    readonly property color cancelButtonTextColor: "#c8ccd4"
    readonly property color cancelButtonHoverTextColor: "#f0f2f5"

    signal accepted(string action)

    color: "transparent"
    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-confirm"

    focusable: confirmWindow.dialogVisible
    visible: confirmWindow.dialogVisible
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

    function request(title, description, icon, danger, timeout, action) {
        confirmWindow.dialogTitle = title;
        confirmWindow.dialogDescription = description;
        confirmWindow.dialogIcon = icon;
        confirmWindow.dialogDanger = danger;
        confirmWindow.dialogTimeout = timeout;
        confirmWindow.dialogAction = action;
        countdown.remaining = timeout;
        closeAnim.stop();
        confirmCard.opacity = 0;
        confirmCard.scale = 0.92;
        confirmWindow.dialogVisible = true;
        countdownTimer.stop();
        openAnim.start();
        if (timeout > 0)
            countdownTimer.start();
    }

    function dismiss() {
        countdownTimer.stop();
        closeAnim.start();
    }

    function executeAction() {
        let action = confirmWindow.dialogAction;
        confirmWindow.dismiss();
        confirmWindow.accepted(action);
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
        focus: confirmWindow.dialogVisible

        Keys.onEscapePressed: function(event) {
            confirmWindow.dismiss();
            event.accepted = true;
        }

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

        ParallelAnimation {
            id: closeAnim
            onFinished: confirmWindow.dialogVisible = false

            NumberAnimation {
                target: confirmCard; property: "opacity"
                from: confirmCard.opacity; to: 0
                duration: 150
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: confirmCard; property: "scale"
                from: confirmCard.scale; to: 0.96
                duration: 150
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
                name: confirmWindow.dialogIcon
                iconColor: confirmWindow.dialogDanger ? Theme.error : Theme.text
                implicitSize: 28
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: confirmWindow.dialogTitle
                color: Theme.text
                font.pixelSize: 22
                font.weight: Font.DemiBold
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: contentCol.width
                text: confirmWindow.dialogDescription
                color: Theme.textSecondary
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            ColumnLayout {
                visible: confirmWindow.dialogTimeout > 0
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
                        color: confirmWindow.dialogDanger ? Theme.error : Theme.primary
                        opacity: 0.7
                        width: confirmWindow.dialogTimeout > 0
                            ? parent.width * (countdown.remaining / confirmWindow.dialogTimeout)
                            : 0

                        Behavior on width {
                            NumberAnimation {
                                duration: 1000
                                easing.type: Easing.Linear
                            }
                        }
                    }
                }

                StyledText {
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
                    textColor: confirmWindow.cancelButtonTextColor
                    hoverTextColor: confirmWindow.cancelButtonHoverTextColor
                    unfilledColor: confirmWindow.cancelButtonColor
                    unfilledHoverColor: confirmWindow.cancelButtonHoverColor
                    unfilledBorderColor: confirmWindow.cancelButtonBorderColor
                    unfilledHoverBorderColor: confirmWindow.cancelButtonHoverBorderColor
                    buttonHeight: 38
                    onClicked: confirmWindow.dismiss()
                }

                ActionButton {
                    Layout.fillWidth: true
                    label: confirmWindow.dialogTitle
                    filled: true
                    danger: confirmWindow.dialogDanger
                    accentColor: confirmWindow.dialogDanger ? Theme.error : Theme.primary
                    buttonHeight: 38
                    onClicked: confirmWindow.executeAction()
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: confirmWindow.dismiss()
    }
}
