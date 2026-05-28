pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property string lastToken: ""
    readonly property string commandFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/hypr-shell/popup-command"

    signal quickSettingsRequested()
    signal audioUpRequested()
    signal audioDownRequested()
    signal audioMuteRequested()
    signal osdRefreshRequested(string osdType)

    function dispatch(text) {
        let trimmed = text.trim();
        if (trimmed.length === 0) return;

        let parts = trimmed.split(/\s+/);
        let token = parts[0] || "";
        let command = parts[1] || "";
        if (token.length === 0 || token === root.lastToken) return;

        root.lastToken = token;
        switch (command) {
            case "quickSettings":
                root.quickSettingsRequested();
                break;
            case "audio-up":
                root.audioUpRequested();
                break;
            case "audio-down":
                root.audioDownRequested();
                break;
            case "audio-mute":
                root.audioMuteRequested();
                break;
            case "osd-volume":
            case "osd-mute":
                root.osdRefreshRequested("volume");
                break;
            case "osd-brightness":
                root.osdRefreshRequested("brightness");
                break;
            case "osd-keyboard":
                root.osdRefreshRequested("keyboard");
                break;
        }
    }

    Process {
        id: seedProcess
        command: ["sh", "-c", "cat '" + root.commandFile + "' 2>/dev/null || true"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let token = this.text.trim().split(/\s+/)[0] || "";
                if (token.length > 0) {
                    root.lastToken = token;
                }
                pollTimer.running = true;
            }
        }
    }

    Process {
        id: commandProcess
        command: ["sh", "-c", "cat '" + root.commandFile + "' 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: root.dispatch(this.text)
        }
    }

    Timer {
        id: pollTimer
        interval: 250
        repeat: true
        onTriggered: commandProcess.running = true
    }
}
