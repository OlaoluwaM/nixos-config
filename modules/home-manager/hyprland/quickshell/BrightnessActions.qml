pragma ComponentBehavior: Bound

import QtQml

QtObject {
    id: root

    required property CommandRunner runner

    function setBrightness(value) {
        root.runner.runAndRefresh(GeneratedCommands.brightnessCommand + " set " + Math.round(value) + "%");
    }

    function adjustBrightness(delta) {
        let op = delta > 0 ? (delta + "%+") : (Math.abs(delta) + "%-");
        root.runner.run(GeneratedCommands.brightnessCommand + " set " + op);
        root.runner.refreshOsd("brightness");
    }

    function adjustKbBacklight(delta) {
        let device = "--device='*::kbd_backlight'";
        let op = delta > 0 ? (delta + "%+") : (Math.abs(delta) + "%-");
        root.runner.run(GeneratedCommands.brightnessCommand + " " + device + " set " + op);
        root.runner.refreshOsd("keyboard");
    }
}
