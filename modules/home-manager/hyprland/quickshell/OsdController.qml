pragma ComponentBehavior: Bound

import QtQml
import Quickshell

Scope {
    id: root

    property string iconName: "volumeHigh"
    property real value: 0

    signal triggered()

    function show(icon, newValue) {
        root.iconName = icon;
        root.value = newValue;
        root.triggered();
    }
}
