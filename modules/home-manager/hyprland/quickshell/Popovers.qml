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
    readonly property int popoverWindowHeight: 780
    readonly property real trayDefaultHeight: 260
    property string renderedPopup: ""
    property string pendingPopup: ""

    // One row per popup. This keeps sizing decisions visible in one place
    // instead of scattering the same activePopup checks through the file.
    readonly property var popupSpecs: ({
        quickSettings:  { source: "QuickSettings.qml",     width: 430, height: 510, margin: 32, align: "right"  },
        calendar:       { source: "CalendarPanel.qml",     width: 700, height: 440, margin: 28, align: "center" },
        tray:           { source: "TrayPanel.qml",         width: 340, height: root.trayDefaultHeight, margin: 36, align: "right"  },
        notifications:  { source: "NotificationPanel.qml", width: 440, height: 670, margin: 32, align: "center" },
        media:          { source: "MediaPanel.qml",        width: 430, height: 280, margin: 32, align: "right"  }
    })

    function popupSpec(name) {
        return popupSpecs[name] || popupSpecs.media;
    }

    color: "transparent"
    aboveWindows: true
    focusable: root.visible
    visible: root.renderedPopup.length > 0

    // Keep the layer surface stable when switching between popups. Resizing the
    // PanelWindow itself can look like a stretch animation even when the card is
    // swapped without an explicit height animation.
    implicitHeight: root.popoverWindowHeight - root.popoverTop

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

        property real trayCardHeight: root.trayDefaultHeight
        property bool cardShown: true

        z: 1
        visible: popoverCard.cardShown
        width: root.popupSpec(root.renderedPopup).width
        height: root.renderedPopup === "tray"
            ? popoverCard.trayCardHeight
            : root.popupSpec(root.renderedPopup).height

        x: root.popupSpec(root.renderedPopup).align === "center"
            ? Math.round((parent.width - width) / 2)
            : parent.width - width - 12

        radius: Theme.popoverRadius
        color: Theme.base
        border.color: Theme.outline
        border.width: 1

        transformOrigin: Item.Top
        opacity: 0
        scale: 0.92
        focus: root.visible

        function loadPopup(name) {
            root.renderedPopup = name;
            if (name === "tray") {
                popoverCard.trayCardHeight = root.trayDefaultHeight;
            }
            popoverLoader.loadPanel();
        }

        function fadeInSwitchedPopup(expectedPopup) {
            if (root.popups.activePopup !== expectedPopup || root.pendingPopup !== expectedPopup) {
                return;
            }

            popoverCard.loadPopup(expectedPopup);
            root.pendingPopup = "";
            popoverCard.cardShown = true;
            popoverCard.opacity = 0;
            popoverCard.scale = 1.0;
            switchInAnim.start();
        }

        function showOpenedPopup(name) {
            popoverCard.loadPopup(name);
            popoverCard.cardShown = true;
            popoverCard.opacity = 0;
            popoverCard.scale = 0.92;
            openAnim.start();
            popoverCard.forceActiveFocus();
        }

        Keys.onEscapePressed: function(event) {
            root.popups.close();
            event.accepted = true;
        }

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

        ParallelAnimation {
            id: closeAnim
            onFinished: {
                if (root.popups.activePopup.length === 0) {
                    popoverLoader.source = "";
                    root.renderedPopup = "";
                }
            }

            NumberAnimation {
                target: popoverCard; property: "opacity"
                from: popoverCard.opacity; to: 0
                duration: 150
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: popoverCard; property: "scale"
                from: popoverCard.scale; to: 0.96
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        NumberAnimation {
            id: switchOutAnim
            target: popoverCard
            property: "opacity"
            from: popoverCard.opacity
            to: 0
            duration: 120
            easing.type: Easing.OutCubic
            onFinished: popoverCard.fadeInSwitchedPopup(root.pendingPopup)
        }

        NumberAnimation {
            id: switchInAnim
            target: popoverCard
            property: "opacity"
            from: 0
            to: 1
            duration: 150
            easing.type: Easing.OutCubic
            onFinished: popoverCard.forceActiveFocus()
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
                    root.pendingPopup = "";
                    switchOutAnim.stop();
                    switchInAnim.stop();
                    popoverCard.cardShown = true;
                    closeAnim.start();
                    return;
                }

                if (root.popups.activePopup.length > 0) {
                    let wasVisible = root.renderedPopup.length > 0;
                    let targetPopup = root.popups.activePopup;
                    closeAnim.stop();
                    openAnim.stop();
                    switchInAnim.stop();
                    if (wasVisible) {
                        root.pendingPopup = targetPopup;
                        popoverCard.cardShown = true;
                        switchOutAnim.restart();
                    } else {
                        root.pendingPopup = "";
                        switchOutAnim.stop();
                        popoverCard.showOpenedPopup(targetPopup);
                    }
                }
            }
            function onTrayMenuContentHeightChanged() {
                if (root.popups.activePopup === "tray") {
                    let trayMargin = root.popupSpec("tray").margin;
                    let target = root.popups.trayMenuContentHeight > 0
                        ? Math.min(root.popups.trayMenuContentHeight + trayMargin * 2, root.implicitHeight)
                        : root.trayDefaultHeight;
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
            anchors.margins: root.popupSpec(root.renderedPopup).margin
            asynchronous: false

            function loadPanel() {
                let popup = root.renderedPopup;
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
                    root.renderedPopup = root.popups.activePopup;
                    loadPanel();
                }
            }
        }
    }
}
