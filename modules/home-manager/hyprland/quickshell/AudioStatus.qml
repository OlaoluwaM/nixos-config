pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Services.Pipewire

Scope {
    id: root

    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property var audio: root.audioSink !== null && root.audioSink.ready ? root.audioSink.audio : null
    readonly property bool hasAudio: root.audio !== null
    readonly property int volumePercent: root.hasAudio ? Math.round(root.audio.volume * 100) : 0
    readonly property string volumeText: root.hasAudio ? root.volumePercent + "%" : "N/A"
    readonly property bool muted: root.hasAudio ? root.audio.muted : false

    PwObjectTracker {
        objects: [root.audioSink]
    }
}
