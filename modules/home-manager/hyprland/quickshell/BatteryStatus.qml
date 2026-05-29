pragma ComponentBehavior: Bound

import QtQml
import Quickshell.Services.UPower

QtObject {
    id: root

    readonly property var batteryDevice: UPower.displayDevice
    readonly property bool batteryReady: root.batteryDevice !== null
        && root.batteryDevice.ready
        && root.batteryDevice.state !== UPowerDeviceState.Unknown
    readonly property int batteryPercent: root.batteryReady
        ? Math.round(root.batteryDevice.percentage * 100)
        : 0
    readonly property bool batteryCharging: root.batteryReady
        && (root.batteryDevice.state === UPowerDeviceState.Charging
            || root.batteryDevice.state === UPowerDeviceState.PendingCharge)
    readonly property bool batteryFull: root.batteryReady
        && root.batteryDevice.state === UPowerDeviceState.FullyCharged
    readonly property string batteryStatusLabel: root.batteryLabel()

    function batteryLabel() {
        if (!root.batteryReady) return qsTr("AC Power");
        if (root.batteryFull) return qsTr("Full");
        if (root.batteryCharging) return qsTr("Charging");
        if (root.batteryDevice.state === UPowerDeviceState.PendingDischarge) return qsTr("On Battery");
        if (root.batteryDevice.state === UPowerDeviceState.Discharging) return qsTr("On Battery");
        return UPower.onBattery ? qsTr("On Battery") : qsTr("AC Power");
    }
}
