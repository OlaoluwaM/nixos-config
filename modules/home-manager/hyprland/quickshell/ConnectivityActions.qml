pragma ComponentBehavior: Bound

import QtQml

QtObject {
    id: root

    required property CommandRunner runner
    required property StatusController status

    function runNetworkCommand() {
        root.runner.run(GeneratedCommands.networkCommand);
    }

    function runBluetoothCommand() {
        root.runner.run(GeneratedCommands.bluetoothCommand);
    }

    function toggleAirplaneMode() {
        root.status.airplaneMode = !root.status.airplaneMode;
        root.runner.runAndRefresh(
            GeneratedCommands.rfkillCommand
                + (root.status.airplaneMode ? " block" : " unblock")
                + " all"
        );
    }
}
