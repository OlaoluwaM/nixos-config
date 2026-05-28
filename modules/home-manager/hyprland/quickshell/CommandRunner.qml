pragma ComponentBehavior: Bound

import QtQml
import Quickshell

QtObject {
    id: root

    signal osdRefreshRequested(string osdType)
    signal statusRefreshRequested()

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function run(command) {
        let script = command
            + "\nstatus=$?"
            + "\nif [ \"$status\" -ne 0 ]; then"
            + "\n  " + GeneratedCommands.notifySendCommand + " --app-name=Quickshell --urgency=normal "
            + root.shellQuote(qsTr("Quickshell command failed"))
            + " \"Exit status: $status; Command: \""
            + root.shellQuote(command)
            + "\nfi"
            + "\nexit \"$status\"";

        Quickshell.execDetached(["sh", "-c", script]);
    }

    function runAndRefresh(command) {
        root.run(command);
        root.statusRefreshRequested();
    }

    function refreshOsd(osdType) {
        root.osdRefreshRequested(osdType);
    }
}
