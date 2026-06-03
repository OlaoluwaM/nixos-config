pragma ComponentBehavior: Bound

import QtQml
import Quickshell

Scope {
    id: root

    required property CommandRunner runner
    required property StatusController status

    signal osdRequested(bool muted, int volumePercent)

    // AudioStatus owns the PipeWire sink and the single PwObjectTracker that
    // keeps its properties live; we read that node here and write volume/mute,
    // then refresh the OSD. CommandRunner is only used for that OSD refresh.
    readonly property var audio: root.status.audioStatus.audio
    readonly property bool ready: root.status.audioStatus.hasAudio

    function setVolume(value) {
        if (root.ready) {
            root.audio.volume = Math.max(0, Math.min(1, Math.round(value) / 100));
        }
    }

    function adjustVolume(delta) {
        if (root.ready) {
            let previousVolume = root.audio.volume;
            let nextVolume = Math.max(0, Math.min(1, root.audio.volume + delta / 100));
            root.audio.volume = nextVolume;
            // If the audio was muted, unmute it when adjusting the volume, and show the OSD with the new volume.
            if (root.audio.muted) {
                root.audio.muted = false;
            }
            root.osdRequested(root.audio.muted, Math.round(nextVolume * 100));
            return;
        }
        root.runner.refreshOsd("volume");
    }

    function toggleMute() {
        if (root.ready) {
            let nextMuted = !root.audio.muted;
            root.audio.muted = nextMuted;
            root.osdRequested(nextMuted, Math.round(root.audio.volume * 100));
            return;
        }
        root.runner.refreshOsd("volume");
    }
}
