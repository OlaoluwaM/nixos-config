pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property AudioActions audioActions
    required property BrightnessActions brightnessActions
    required property ConnectivityActions connectivityActions
    required property MediaActions mediaActions
    required property PowerActions powerActions
    required property StatusController status
    required property NotificationService notifications
    required property PopupController popups

    readonly property int topbarBottom: 70
    readonly property int topbarGap: 18
    readonly property int popoverTop: root.topbarBottom + root.topbarGap

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
    visible: root.popups.activePopup.length > 0

    implicitHeight: root.popupSpec(root.popups.activePopup).windowHeight - root.popoverTop

    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-popover"

    margins {
        top: root.popoverTop
    }

    anchors {
        top: true
        left: true
        right: true
    }

    MouseArea {
        anchors.fill: parent
        z: 0
        onClicked: root.popups.close()
    }

    // ── Popover card ───────────────────────────────────────────────────
    Rectangle {
        id: popoverCard

        property real trayCardHeight: 260

        z: 1
        width: root.popupSpec(root.popups.activePopup).width
        height: root.popups.activePopup === "tray"
            ? popoverCard.trayCardHeight
            : root.popupSpec(root.popups.activePopup).height

        x: root.popupSpec(root.popups.activePopup).align === "center"
            ? Math.round((parent.width - width) / 2)
            : parent.width - width - 12

        radius: Theme.popoverRadius
        color: Theme.base
        border.color: Theme.outline
        border.width: 1

        transformOrigin: Item.Top
        opacity: 0
        scale: 0.92

        MouseArea { anchors.fill: parent }

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
            target: root.popups
            function onActivePopupChanged() {
                if (root.popups.activePopup === "") {
                    root.popups.trayMenuContentHeight = 0;
                    popoverLoader.source = "";
                    return;
                }

                if (root.popups.activePopup.length > 0) {
                    if (root.popups.activePopup === "tray") {
                        popoverCard.trayCardHeight = 260;
                    }
                    popoverCard.opacity = 0;
                    popoverCard.scale = 0.92;
                    openAnim.start();
                    popoverLoader.loadPanel();
                }
            }
            function onTrayMenuContentHeightChanged() {
                if (root.popups.activePopup === "tray") {
                    let target = root.popups.trayMenuContentHeight > 0
                        ? Math.min(root.popups.trayMenuContentHeight + 72, 500)
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
                    root.popups.trayPopoverHovered = root.popups.activePopup === "tray";
                }
            }
        }

        Loader {
            id: popoverLoader
            anchors.fill: parent
            anchors.margins: root.popupSpec(root.popups.activePopup).margin
            asynchronous: false

            function loadPanel() {
                let popup = root.popups.activePopup;
                let src = root.popupSpec(popup).source;
                if (src) {
                    let props = {};
                    if (popup === "quickSettings" || popup === "media") {
                        props.status = root.status;
                    }
                    if (popup === "quickSettings") {
                        props.audioActions = root.audioActions;
                        props.brightnessActions = root.brightnessActions;
                        props.connectivityActions = root.connectivityActions;
                        props.powerActions = root.powerActions;
                    }
                    if (popup === "media") {
                        props.mediaActions = root.mediaActions;
                    }
                    if (popup === "quickSettings" || popup === "notifications") {
                        props.notifications = root.notifications;
                    }
                    if (popup === "tray") {
                        props.popups = root.popups;
                    }
                    popoverLoader.setSource(src, props);
                } else {
                    popoverLoader.source = "";
                }
            }

            Component.onCompleted: {
                if (root.popups.activePopup.length > 0) {
                    loadPanel();
                }
            }
        }
    }
}
