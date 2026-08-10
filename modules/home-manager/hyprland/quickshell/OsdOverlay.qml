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

    // Clip input to the small OSD card. The window is a full-width bottom strip,
    // so without this it would intercept clicks across the whole bottom edge for
    // ~1.8s on every volume/brightness key press.
    mask: Region { item: osdCard }

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
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 10
        }
        width: 260
        height: 64
        // Same card idiom as NotificationCard, so share its radius token rather
        // than a one-off 16 — keeps all base-surface cards visually consistent.
        radius: Theme.cardRadius
        color: Theme.base
        border.color: Theme.outline
        border.width: 1
        opacity: 0

        ParallelAnimation {
            id: showAnim
            NumberAnimation {
                target: osdCard; property: "opacity"
                to: 1; duration: Theme.animFast
                easing.type: Theme.easingType
                easing.bezierCurve: Theme.easingDecel
            }
            NumberAnimation {
                target: osdCard; property: "anchors.bottomMargin"
                to: 40; duration: Theme.animFade
                easing.type: Theme.easingType
                easing.bezierCurve: Theme.easingDecel
            }
        }

        ParallelAnimation {
            id: hideAnim
            NumberAnimation {
                target: osdCard; property: "opacity"
                to: 0; duration: Theme.animNormal
                easing.type: Theme.easingType
                easing.bezierCurve: Theme.easingAccel
            }
            NumberAnimation {
                target: osdCard; property: "anchors.bottomMargin"
                to: 10; duration: Theme.animNormal
                easing.type: Theme.easingType
                easing.bezierCurve: Theme.easingAccel
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
                radius: Theme.trackRadius
                color: Theme.surfaceVariant

                Rectangle {
                    id: osdFill
                    readonly property var fillGradient: Theme.osdGradient(osdWindow.osd.value)

                    width: Math.max(0, Math.min(1, osdWindow.osd.value / 100)) * parent.width
                    height: parent.height
                    radius: Theme.trackRadius
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: osdFill.fillGradient.start }
                        GradientStop { position: 1.0; color: osdFill.fillGradient.end }
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.animFast
                            easing.type: Theme.easingType
                            easing.bezierCurve: Theme.easingCurve
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
