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

    readonly property int topbarBottom: Theme.barTopMargin + Theme.barHeight
    readonly property int popoverTop: root.topbarBottom + Theme.popoverGap
    readonly property real trayDefaultHeight: 260
    property string renderedPopup: ""
    property string pendingPopup: ""

    readonly property var popupSpecs: ({
        quickSettings:  { source: "QuickSettings.qml",     width: Theme.popoverStandardWidth, height: 510, padding: Theme.popoverPadding, align: "right" },
        calendar:       { source: "CalendarPanel.qml",     width: Theme.popoverWideWidth,     height: 440, padding: Theme.popoverPadding, align: "center" },
        tray:           { source: "TrayPanel.qml",         width: Theme.popoverCompactWidth,  height: root.trayDefaultHeight, padding: Theme.popoverCompactPadding, align: "right" },
        notifications:  { source: "NotificationPanel.qml", width: Theme.popoverStandardWidth, height: 670, padding: Theme.popoverPadding, align: "center" },
        media:          { source: "MediaPanel.qml",        width: Theme.popoverStandardWidth, height: 300, padding: Theme.popoverPadding, align: "left" }
    })

    function popupSpec(name) {
        return popupSpecs[name] || popupSpecs.media;
    }

    color: "transparent"
    aboveWindows: true
    focusable: root.visible
    visible: root.renderedPopup.length > 0
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-popover"

    margins {
        top: root.popoverTop
        bottom: Theme.popoverScreenInset
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    MouseArea {
        anchors.fill: parent
        z: 0
        onClicked: root.popups.close()
    }

    PopoverFrame {
        id: popoverCard

        property real trayCardHeight: root.trayDefaultHeight
        property bool cardShown: true
        property real shownAnchorCenterX: -1

        z: 1
        visible: popoverCard.cardShown
        width: Math.min(root.popupSpec(root.renderedPopup).width, parent.width - Theme.popoverScreenInset * 2)
        height: {
            if (root.renderedPopup === "tray")
                return Math.min(popoverCard.trayCardHeight, parent.height - Theme.popoverBottomClearance);
            if (root.renderedPopup === "media" && popoverLoader.status === Loader.Ready)
                return Math.min(Math.round(popoverLoader.item.implicitHeight) + contentPadding * 2, parent.height - Theme.popoverBottomClearance);
            return Math.min(root.popupSpec(root.renderedPopup).height, parent.height - Theme.popoverBottomClearance);
        }
        x: {
            if (popoverCard.shownAnchorCenterX >= 0) {
                let centered = popoverCard.shownAnchorCenterX - width / 2;
                return Math.round(Math.max(Theme.popoverScreenInset, Math.min(centered, parent.width - width - Theme.popoverScreenInset)));
            }
            if (root.popupSpec(root.renderedPopup).align === "center")
                return Math.round((parent.width - width) / 2);
            if (root.popupSpec(root.renderedPopup).align === "left")
                return Theme.popoverScreenInset;
            return parent.width - width - Theme.popoverScreenInset;
        }
        y: 0
        contentPadding: root.popupSpec(root.renderedPopup).padding
        opacity: 0
        focus: root.visible

        function loadPopup(name) {
            root.renderedPopup = name;
            if (name === "tray")
                popoverCard.trayCardHeight = root.trayDefaultHeight;
            popoverLoader.loadPanel();
        }

        function fadeInSwitchedPopup(expectedPopup) {
            const popupIsCurrent = root.popups.activePopup === expectedPopup
                && root.pendingPopup === expectedPopup;
            if (!popupIsCurrent)
                return;

            popoverCard.shownAnchorCenterX = root.popups.anchorCenterX;
            popoverCard.loadPopup(expectedPopup);
            root.pendingPopup = "";
            popoverCard.cardShown = true;
            popoverCard.opacity = 0;
            popoverCard.y = 0;
            switchInAnim.start();
        }

        function showOpenedPopup(name) {
            popoverCard.shownAnchorCenterX = root.popups.anchorCenterX;
            popoverCard.loadPopup(name);
            popoverCard.cardShown = true;
            popoverCard.opacity = 0;
            popoverCard.y = Theme.popoverMotionDistanceOpen;
            openAnim.start();
            popoverCard.forceActiveFocus();
        }

        Keys.onEscapePressed: function(event) {
            root.popups.close();
            event.accepted = true;
        }

        ParallelAnimation {
            id: openAnim
            NumberAnimation {
                target: popoverCard
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.popoverMotionDuration
                easing.type: Theme.easingType
                easing.bezierCurve: Theme.easingDecel
            }
            NumberAnimation {
                target: popoverCard
                property: "y"
                from: Theme.popoverMotionDistanceOpen
                to: 0
                duration: Theme.popoverMotionDuration
                easing.type: Theme.easingType
                easing.bezierCurve: Theme.easingDecel
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
                target: popoverCard
                property: "opacity"
                from: popoverCard.opacity
                to: 0
                duration: Theme.popoverMotionDuration
                easing.type: Theme.easingType
                easing.bezierCurve: Theme.easingAccel
            }
            NumberAnimation {
                target: popoverCard
                property: "y"
                from: popoverCard.y
                to: Theme.popoverMotionDistanceClose
                duration: Theme.popoverMotionDuration
                easing.type: Theme.easingType
                easing.bezierCurve: Theme.easingAccel
            }
        }

        NumberAnimation {
            id: switchOutAnim
            target: popoverCard
            property: "opacity"
            from: popoverCard.opacity
            to: 0
            duration: Theme.popoverMotionDuration
            easing.type: Theme.easingType
            easing.bezierCurve: Theme.easingAccel
            onFinished: popoverCard.fadeInSwitchedPopup(root.pendingPopup)
        }

        NumberAnimation {
            id: switchInAnim
            target: popoverCard
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.popoverMotionDuration
            easing.type: Theme.easingType
            easing.bezierCurve: Theme.easingDecel
            onFinished: popoverCard.forceActiveFocus()
        }

        Behavior on trayCardHeight {
            NumberAnimation {
                duration: Theme.animNormal
                easing.type: Theme.easingType
                easing.bezierCurve: Theme.easingCurve
            }
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
            function onTrayMenuContentHeightChanged() {
                if (root.popups.activePopup === "tray") {
                    let trayPadding = root.popupSpec("tray").padding;
                    let target = root.popups.trayMenuContentHeight > 0
                        ? Math.min(root.popups.trayMenuContentHeight + trayPadding * 2, root.height - Theme.popoverBottomClearance)
                        : root.trayDefaultHeight;
                    popoverCard.trayCardHeight = target;
                }
            }
        }

        Loader {
            id: popoverLoader
            parent: popoverCard.contentItem
            anchors.fill: parent
            active: root.renderedPopup.length > 0
            asynchronous: false

            function loadPanel() {
                let popup = root.renderedPopup;
                let src = root.popupSpec(popup).source;
                if (src) {
                    let props = {};
                    if (popup === "quickSettings" || popup === "media")
                        props.status = root.status;
                    if (popup === "quickSettings") {
                        props.audioActions = root.audioActions;
                        props.brightnessActions = root.brightnessActions;
                        props.connectivityActions = root.connectivityActions;
                        props.powerActions = root.powerActions;
                    }
                    if (popup === "media")
                        props.mediaActions = root.mediaActions;
                    if (popup === "quickSettings" || popup === "notifications")
                        props.notifications = root.notifications;
                    if (popup === "tray")
                        props.popups = root.popups;
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
