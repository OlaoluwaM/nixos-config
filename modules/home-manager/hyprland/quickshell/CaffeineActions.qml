pragma ComponentBehavior: Bound

import QtQml

QtObject {
    id: root

    required property CommandRunner runner
    required property StatusController status

    property bool commandPending: false

    function setManual(enabled) {
        if (root.commandPending || root.status.caffeineManual === enabled) return;

        root.commandPending = true;
        root.status.caffeineManual = enabled;
        root.runner.runAndRefresh(GeneratedCommands.caffeineCommand + (enabled ? " on" : " off"));
        commandSettleTimer.restart();
    }

    function toggleManual() {
        root.setManual(!root.status.caffeineManual);
    }

    Timer {
        id: commandSettleTimer

        interval: 900
        onTriggered: root.commandPending = false
    }
}
