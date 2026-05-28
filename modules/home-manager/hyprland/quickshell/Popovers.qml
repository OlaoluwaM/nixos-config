pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: popoverWindow
    required property var shell
    required property var notifications
    required property var popups

    // One row per popup. This keeps sizing decisions visible in one place
    // instead of scattering the same activePopup checks through the file.
    readonly property var popupSpecs: ({
        quickSettings:  { source: "QuickSettings.qml",     width: 430, height: 510, windowHeight: 600, margin: 32, align: "right"  },
        calendar:       { source: "CalendarPanel.qml",     width: 700, height: 440, windowHeight: 530, margin: 28, align: "center" },
        tray:           { source: "TrayPanel.qml",         width: 340, height: 260, windowHeight: 650, margin: 36, align: "right"  },
        notifications:  { source: "NotificationPanel.qml", width: 440, height: 670, windowHeight: 780, margin: 32, align: "center" },
        media:          { source: "MediaPanel.qml",        width: 430, height: 280, windowHeight: 430, margin: 32, align: "right"  }
    })

    function popupSpec(name) {
        return popupSpecs[name] || popupSpecs.media;
    }

    color: "transparent"
    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-popover"

    visible: popoverWindow.popups.activePopup !== ""

    implicitHeight: popoverWindow.popupSpec(popoverWindow.popups.activePopup).windowHeight

    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        left: true
        right: true
    }

    // ── Popover card ───────────────────────────────────────────────────
    Rectangle {
        id: popoverCard
        y: 70

        property real trayCardHeight: 260

        width: popoverWindow.popupSpec(popoverWindow.popups.activePopup).width
        height: popoverWindow.popups.activePopup === "tray"
            ? popoverCard.trayCardHeight
            : popoverWindow.popupSpec(popoverWindow.popups.activePopup).height

        x: popoverWindow.popupSpec(popoverWindow.popups.activePopup).align === "center"
            ? Math.round((parent.width - width) / 2)
            : parent.width - width - 12

        radius: Theme.popoverRadius
        color: Theme.base
        border.color: Theme.outline
        border.width: 1

        MouseArea { anchors.fill: parent }

        transformOrigin: Item.Top
        opacity: 0
        scale: 0.92

        ParallelAnimation {
            id: openAnim
            NumberAnimation {
                target: popoverCard; property: "opacity"
                from: 0; to: 1
                duration: Theme.animFade
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: popoverCard; property: "scale"
                from: 0.92; to: 1.0
                duration: Theme.animNormal
                easing.type: Easing.OutCubic
            }
        }

        NumberAnimation {
            id: trayHeightAnim
            target: popoverCard
            property: "trayCardHeight"
            duration: 300
            easing.type: Theme.easingType
            easing.bezierCurve: Theme.easingCurve
        }

        Connections {
            target: popoverWindow.popups
            function onActivePopupChanged() {
                if (popoverWindow.popups.activePopup === "") {
                    popoverWindow.popups.trayMenuContentHeight = 0;
                    popoverLoader.source = "";
                    return;
                }

                if (popoverWindow.popups.activePopup !== "") {
                    if (popoverWindow.popups.activePopup === "tray") {
                        popoverCard.trayCardHeight = 260;
                    }
                    popoverCard.opacity = 0;
                    popoverCard.scale = 0.92;
                    openAnim.start();
                    popoverLoader.loadPanel();
                }
            }
            function onTrayMenuContentHeightChanged() {
                if (popoverWindow.popups.activePopup === "tray") {
                    let target = popoverWindow.popups.trayMenuContentHeight > 0
                        ? Math.min(popoverWindow.popups.trayMenuContentHeight + 72, 500)
                        : 260;
                    trayHeightAnim.stop();
                    trayHeightAnim.from = popoverCard.trayCardHeight;
                    trayHeightAnim.to = target;
                    trayHeightAnim.start();
                }
            }
        }

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    popoverWindow.popups.trayPopoverHovered = popoverWindow.popups.activePopup === "tray";
                }
            }
        }

        Loader {
            id: popoverLoader
            anchors.fill: parent
            anchors.margins: popoverWindow.popupSpec(popoverWindow.popups.activePopup).margin
            asynchronous: false

            function loadPanel() {
                let popup = popoverWindow.popups.activePopup;
                let src = popoverWindow.popupSpec(popup).source;
                if (src) {
                    let props = {};
                    if (popup !== "calendar" && popup !== "notifications" && popup !== "tray") {
                        props.shell = popoverWindow.shell;
                    }
                    if (popup === "quickSettings" || popup === "notifications") {
                        props.notifications = popoverWindow.notifications;
                    }
                    if (popup === "tray") {
                        props.popups = popoverWindow.popups;
                    }
                    popoverLoader.setSource(src, props);
                } else {
                    popoverLoader.source = "";
                }
            }

            Component.onCompleted: {
                if (popoverWindow.popups.activePopup !== "") {
                    loadPanel();
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: popoverWindow.popups.close()
    }
}
