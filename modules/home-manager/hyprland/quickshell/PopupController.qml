pragma ComponentBehavior: Bound

import QtQml
import Quickshell

Scope {
    id: root

    property int trayItemCount: 0
    property string activePopup: ""
    // Screen-x the open popup should center under (set by the triggering capsule);
    // -1 means "no anchor" → fall back to the spec's edge alignment.
    property real anchorCenterX: -1
    property real trayMenuContentHeight: 0

    function toggle(name) {
        root.anchorCenterX = -1;
        root.activePopup = root.activePopup === name ? "" : name;
    }

    // Like toggle(), but anchors the popup under the triggering capsule.
    function toggleAt(name, centerX) {
        let opening = root.activePopup !== name;
        root.anchorCenterX = opening ? centerX : -1;
        root.activePopup = opening ? name : "";
    }

    function close() {
        root.trayMenuContentHeight = 0;
        root.activePopup = "";
    }
}
