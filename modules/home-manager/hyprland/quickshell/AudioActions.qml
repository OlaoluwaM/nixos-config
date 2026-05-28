pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Services.Pipewire

Scope {
    id: root

    required property CommandRunner runner

    // PipeWire owns the audio state; CommandRunner is only used to refresh the
    // brightness/volume OSD after keybind-driven changes.
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property var audio: root.audioSink !== null && root.audioSink.ready ? root.audioSink.audio : null
    readonly property bool ready: root.audio !== null

    function setVolume(value) {
        if (root.ready) {
            root.audio.volume = Math.max(0, Math.min(1, Math.round(value) / 100));
        }
    }

    function adjustVolume(delta) {
        if (root.ready) {
            root.audio.volume = Math.max(0, Math.min(1, root.audio.volume + delta / 100));
        }
        root.runner.refreshOsd("volume");
    }

    function toggleMute() {
        if (root.ready) {
            root.audio.muted = !root.audio.muted;
        }
        root.runner.refreshOsd("volume");
    }

    PwObjectTracker {
        objects: [root.audioSink]
    }
}
