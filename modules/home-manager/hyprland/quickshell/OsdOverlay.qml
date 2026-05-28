pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: osdWindow
    required property var osd

    color: "transparent"
    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"

    visible: osdState.windowVisible
    implicitWidth: 280
    implicitHeight: 120
    exclusionMode: ExclusionMode.Ignore

    anchors {
        bottom: true
        left: true
        right: true
    }

    QtObject {
        id: osdState
        property bool windowVisible: false
    }

    Rectangle {
        id: osdCard
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        width: 260
        height: 64
        radius: 16
        color: Theme.base
        border.color: Theme.outline
        border.width: 1
        opacity: 0

        ParallelAnimation {
            id: showAnim
            NumberAnimation {
                target: osdCard; property: "opacity"
                to: 1; duration: 150
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: osdCard; property: "anchors.bottomMargin"
                to: 40; duration: 200
                easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {
            id: hideAnim
            NumberAnimation {
                target: osdCard; property: "opacity"
                to: 0; duration: 300
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: osdCard; property: "anchors.bottomMargin"
                to: 10; duration: 350
                easing.type: Easing.InCubic
            }
            onFinished: osdState.windowVisible = false
        }

        Row {
            anchors.centerIn: parent
            spacing: 14

            ShellIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: osdWindow.osd.iconName
                iconColor: Theme.text
                implicitSize: 20
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 170
                height: 6
                radius: 3
                color: Theme.surfaceVariant

                Rectangle {
                    width: Math.max(0, Math.min(1, osdWindow.osd.value / 100)) * parent.width
                    height: parent.height
                    radius: 3
                    color: Theme.primary

                    Behavior on width {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }

        Timer {
            id: hideTimer
            interval: 1500
            onTriggered: {
                showAnim.stop();
                hideAnim.start();
            }
        }

        Connections {
            target: osdWindow.osd
            function onTriggered() {
                hideAnim.stop();
                osdState.windowVisible = true;
                showAnim.stop();
                showAnim.start();
                hideTimer.restart();
            }
        }
    }
}
