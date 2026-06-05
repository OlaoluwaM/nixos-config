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
    readonly property int lowBatteryThreshold: 30
    readonly property int warningBatteryThreshold: 50
    readonly property int neutralBatteryThreshold: 65
    readonly property bool batteryCharging: root.batteryReady
        && root.batteryDevice.state === UPowerDeviceState.Charging
    readonly property bool batteryPendingCharge: root.batteryReady
        && root.batteryDevice.state === UPowerDeviceState.PendingCharge
    readonly property bool batteryFull: root.batteryReady
        && root.batteryDevice.state === UPowerDeviceState.FullyCharged
    readonly property string batteryIconName: root.batteryIcon()
    readonly property string batteryVisualState: root.batteryState()
    readonly property string batteryStatusLabel: root.batteryLabel()

    function batteryIcon() {
        if (!root.batteryReady) return "onAC";
        if (root.batteryCharging) return "batteryCharging";
        if (root.batteryPendingCharge && !UPower.onBattery) return "onAC";
        if (!UPower.onBattery) return "onAC";
        if (root.batteryPercent < root.lowBatteryThreshold) return "batteryLow";
        return root.batteryPercent < root.neutralBatteryThreshold ? "batteryMid" : "batteryFull";
    }

    function batteryState() {
        if (!root.batteryReady || root.batteryCharging || root.batteryFull || !UPower.onBattery)
            return "success";
        if (root.batteryPercent < root.lowBatteryThreshold) return "error";
        if (root.batteryPercent < root.warningBatteryThreshold) return "warning";
        if (root.batteryPercent <= root.neutralBatteryThreshold) return "neutral";
        return "success";
    }

    function batteryLabel() {
        if (!root.batteryReady) return qsTr("AC Power");
        if (root.batteryFull) return qsTr("Full");
        if (root.batteryCharging) return qsTr("Charging");
        if (root.batteryPendingCharge && !UPower.onBattery) return qsTr("AC Power");
        if (root.batteryDevice.state === UPowerDeviceState.PendingDischarge) return qsTr("On Battery");
        if (root.batteryDevice.state === UPowerDeviceState.Discharging) return qsTr("On Battery");
        return UPower.onBattery ? qsTr("On Battery") : qsTr("AC Power");
    }
}
