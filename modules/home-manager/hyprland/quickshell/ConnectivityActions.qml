pragma ComponentBehavior: Bound

import QtQml
import Quickshell

// Scope (not QtObject) so the child Timer has a default property to attach to.
Scope {
    id: root

    required property CommandRunner runner
    required property StatusController status

    property bool airplaneCommandPending: false

    function runNetworkCommand() {
        root.runner.run(GeneratedCommands.networkCommand);
    }

    function runBluetoothCommand() {
        root.runner.run(GeneratedCommands.bluetoothCommand);
    }

    function setAirplaneMode(enabled) {
        if (root.airplaneCommandPending || root.status.airplaneMode === enabled) return;

        root.airplaneCommandPending = true;
        root.status.airplaneMode = enabled;
        root.runner.runAndRefresh(
            GeneratedCommands.rfkillCommand
                + (enabled ? " block" : " unblock")
                + " all"
        );
        airplaneCommandSettleTimer.restart();
    }

    function toggleAirplaneMode() {
        root.setAirplaneMode(!root.status.airplaneMode);
    }

    Timer {
        id: airplaneCommandSettleTimer

        interval: 900
        onTriggered: root.airplaneCommandPending = false
    }
}
