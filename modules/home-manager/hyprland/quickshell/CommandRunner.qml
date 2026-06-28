pragma ComponentBehavior: Bound

import QtQml
import Quickshell

Scope {
    id: root

    property string delayedOsdType: ""

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

        Quickshell.execDetached([GeneratedCommands.shellCommand, "-c", script]);
    }

    function runAndRefresh(command) {
        root.run(command);
        root.statusRefreshRequested();
    }

    function refreshOsd(osdType) {
        root.osdRefreshRequested(osdType);
    }

    function refreshOsdDelayed(osdType) {
        root.delayedOsdType = osdType;
        // Coalesce instead of restart: key-hold repeats fire every 85ms, so
        // restarting a 120ms timer each time would defer it forever and freeze
        // the OSD until release. Leaving a pending timer alone lets it fire mid-
        // hold and re-arm on the next change, so the OSD tracks the held key.
        if (!delayedOsdRefreshTimer.running)
            delayedOsdRefreshTimer.start();
    }

    // Brightness changes run through detached brightnessctl commands. Wait a
    // beat (120ms in this case) before the OSD re-reads the device, otherwise it can show the old
    // value because the sysfs write has not landed yet.
    Timer {
        id: delayedOsdRefreshTimer
        interval: 120
        onTriggered: root.osdRefreshRequested(root.delayedOsdType)
    }
}
