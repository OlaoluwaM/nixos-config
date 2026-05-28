pragma ComponentBehavior: Bound

import QtQml

QtObject {
    id: root

    required property CommandRunner runner

    signal confirmationRequested(string title, string description, string icon, bool danger, int timeout, string action)

    function runPowerOffCommand() {
        root.runner.run(GeneratedCommands.powerCommand);
    }

    function runRebootCommand() {
        root.runner.run(GeneratedCommands.rebootCommand);
    }

    function runPowerProfileCycle() {
        root.runner.runAndRefresh(GeneratedCommands.powerProfileCommand + " cycle");
    }

    function runPowerProfileSet(profile) {
        root.runner.runAndRefresh(GeneratedCommands.powerProfileCommand + " set " + profile);
    }

    function runLockCommand() {
        root.runner.run(GeneratedCommands.lockCommand);
    }

    function runSleepCommand() {
        root.runner.run(GeneratedCommands.sleepCommand);
    }

    function runRefreshCommand() {
        root.runner.run(GeneratedCommands.refreshCommand);
    }

    function runLogoutCommand() {
        root.runner.run(GeneratedCommands.logoutCommand);
    }

    function requestLogout() {
        root.confirmationRequested(qsTr("Log Out"), qsTr("Your session will end."), "logout", false, 60, "logout");
    }

    function requestReboot() {
        root.confirmationRequested(qsTr("Restart"), qsTr("The system will restart."), "refresh", false, 60, "reboot");
    }

    function requestSuspend() {
        root.confirmationRequested(qsTr("Suspend"), qsTr("The system will go to sleep."), "sleep", false, 60, "suspend");
    }

    function requestPowerOff() {
        root.confirmationRequested(qsTr("Power Off"), qsTr("The system will shut down."), "power", true, 60, "poweroff");
    }
}
