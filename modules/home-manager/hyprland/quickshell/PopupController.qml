pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Scope {
    id: root

    property int trayItemCount: 0
    property string activePopup: ""
    property bool trayButtonHovered: false
    property bool trayPopoverHovered: false
    property bool trayPinned: false
    property real trayMenuContentHeight: 0

    function toggle(name) {
        if (name !== "tray") root.trayPinned = false;
        root.activePopup = root.activePopup === name ? "" : name;
    }

    function close() {
        root.trayPinned = false;
        root.trayMenuContentHeight = 0;
        root.activePopup = "";
    }

    function openTray(pinned) {
        if (root.trayItemCount === 0) return;
        root.trayPinned = pinned;
        root.activePopup = "tray";
        trayCloseTimer.stop();
    }

    function scheduleTrayClose() {
        if (root.activePopup === "tray" && !root.trayPinned) trayCloseTimer.restart();
    }

    function maybeCloseTray() {
        if (root.activePopup === "tray" && !root.trayPinned
                && !root.trayButtonHovered && !root.trayPopoverHovered) {
            root.activePopup = "";
        }
    }

    Timer {
        id: trayCloseTimer
        interval: 260
        onTriggered: root.maybeCloseTray()
    }
}
