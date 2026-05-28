pragma ComponentBehavior: Bound

import QtQml

QtObject {
    id: root

    required property CommandRunner runner

    function runPlayerctl(action) {
        root.runner.runAndRefresh(GeneratedCommands.playerctlCommand + " " + action);
    }
}
