pragma ComponentBehavior: Bound

import QtQml

QtObject {
    id: root

    required property CommandRunner runner

    function setVolume(value) {
        root.runner.runAndRefresh(GeneratedCommands.pamixerCommand + " --set-volume " + Math.round(value));
    }

    function adjustVolume(delta) {
        let flag = delta > 0 ? "-i" : "-d";
        root.runner.run(GeneratedCommands.pamixerCommand + " " + flag + " " + Math.abs(delta));
        root.runner.refreshOsd("volume");
    }

    function toggleMute() {
        root.runner.run(GeneratedCommands.pamixerCommand + " -t");
        root.runner.refreshOsd("volume");
    }
}
