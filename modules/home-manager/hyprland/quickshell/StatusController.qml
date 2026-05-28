pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Scope {
    id: root

    // Native services own the domains with first-class Quickshell integrations.
    // The shell status script below only fills command-backed fields such as
    // CPU, memory, temperature, brightness, network, Bluetooth, and profiles.
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property var audio: root.audioSink !== null && root.audioSink.ready ? root.audioSink.audio : null
    readonly property bool hasAudio: root.audio !== null

    readonly property var batteryDevice: UPower.displayDevice
    readonly property bool batteryReady: root.batteryDevice !== null
        && root.batteryDevice.ready
        && root.batteryDevice.state !== UPowerDeviceState.Unknown

    readonly property var mediaPlayers: Mpris.players.values
    readonly property var mediaPlayer: root.pickMediaPlayer(root.mediaPlayers)

    property bool airplaneMode: false

    property string clockText: "Loading"
    property string cpuText: "..."
    property string memText: "..."
    property string tempText: "..."
    readonly property int volumePercent: root.hasAudio ? Math.round(root.audio.volume * 100) : 0
    readonly property string volumeText: root.hasAudio ? root.volumePercent + "%" : "N/A"
    readonly property bool muted: root.hasAudio ? root.audio.muted : false
    property string brightnessText: "N/A"
    property string powerProfileText: "Unavailable"
    readonly property int batteryPercent: root.batteryReady
        ? Math.round(root.batteryDevice.percentage * 100)
        : 0
    readonly property bool batteryCharging: root.batteryReady
        && (root.batteryDevice.state === UPowerDeviceState.Charging
            || root.batteryDevice.state === UPowerDeviceState.PendingCharge)
    readonly property bool batteryFull: root.batteryReady
        && root.batteryDevice.state === UPowerDeviceState.FullyCharged
    readonly property string batteryText: root.batteryReady ? root.batteryPercent + "%" : "AC"
    readonly property string batteryHours: root.formatHours(root.batteryTimeSeconds)
    readonly property string batteryMinutes: root.formatMinutes(root.batteryTimeSeconds)
    readonly property string batteryStatusLabel: root.batteryLabel()
    readonly property real batteryTimeSeconds: !root.batteryReady ? 0
        : root.batteryCharging ? root.batteryDevice.timeToFull
        : root.batteryDevice.timeToEmpty
    property string networkText: "Offline"
    property string vpnText: "Off"
    property string bluetoothText: "Off"
    property string bluetoothDevice: ""
    readonly property string mediaStatus: root.mediaPlaybackStatus(root.mediaPlayer)
    readonly property string mediaTitle: root.mediaTrackTitle
    readonly property string mediaArtist: root.mediaPlayer !== null ? root.mediaPlayer.trackArtist : ""
    readonly property string mediaTrackTitle: root.mediaPlayer !== null
        ? (root.mediaPlayer.trackTitle || qsTr("No media"))
        : qsTr("No media")
    readonly property string mediaAlbumArt: root.mediaPlayer !== null ? root.mediaPlayer.trackArtUrl : ""
    readonly property string mediaPosition: root.mediaPlayer !== null
        ? root.formatDuration(root.mediaPlayer.position)
        : "0:00"
    readonly property string mediaLength: root.mediaPlayer !== null
        ? root.formatDuration(root.mediaPlayer.length)
        : "0:00"
    property string localTime: "Loading"
    property string birminghamTime: "..."
    property string lagosTime: "..."
    property string sanFranciscoTime: "..."

    readonly property bool mediaActive: root.mediaStatus === "Playing" || root.mediaStatus === "Paused"
    readonly property string mediaDisplayTitle:
        root.mediaArtist.length > 0 && root.mediaTrackTitle.length > 0
            ? root.mediaArtist + " — " + root.mediaTrackTitle
            : root.mediaTrackTitle

    function isUnavailable(value) {
        return value === "" || value === "--" || value === "N/A" || value === "Unavailable";
    }

    function pickMediaPlayer(players) {
        for (let i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing) return players[i];
        }
        for (let j = 0; j < players.length; j++) {
            if (players[j].playbackState === MprisPlaybackState.Paused) return players[j];
        }
        return players.length > 0 ? players[0] : null;
    }

    function mediaPlaybackStatus(player) {
        if (player === null) return "Stopped";
        if (player.playbackState === MprisPlaybackState.Playing) return "Playing";
        if (player.playbackState === MprisPlaybackState.Paused) return "Paused";
        return "Stopped";
    }

    function formatDuration(seconds) {
        let total = Math.max(0, Math.floor(Number(seconds) || 0));
        return Math.floor(total / 60) + ":" + String(total % 60).padStart(2, "0");
    }

    function formatHours(seconds) {
        if (seconds <= 0) return "--";
        return String(Math.floor(seconds / 3600));
    }

    function formatMinutes(seconds) {
        if (seconds <= 0) return "--";
        return String(Math.floor((seconds % 3600) / 60));
    }

    function batteryLabel() {
        if (!root.batteryReady) return qsTr("AC Power");
        if (root.batteryFull) return qsTr("Full");
        if (root.batteryCharging) return qsTr("Charging");
        if (root.batteryDevice.state === UPowerDeviceState.PendingDischarge) return qsTr("On Battery");
        if (root.batteryDevice.state === UPowerDeviceState.Discharging) return qsTr("On Battery");
        return UPower.onBattery ? qsTr("On Battery") : qsTr("AC Power");
    }

    function updateStatus(data) {
        root.cpuText = data.cpu + "%";
        root.memText = data.mem + "%";
        root.tempText = root.isUnavailable(data.temp) ? "N/A" : data.temp + "°C";
        root.brightnessText = data.brightness;
        root.networkText = data.network;
        root.vpnText = data.vpn;
        root.bluetoothText = data.bluetooth;
        root.bluetoothDevice = data.bluetoothDevice || "";
        root.powerProfileText = data.powerProfile;
    }

    function updateOsdReadings(brightness) {
        if (brightness >= 0) {
            root.brightnessText = brightness + "%";
        }
    }

    function updateTimezones(data) {
        root.clockText = data.local;
        root.localTime = data.local;
        root.birminghamTime = data.birmingham;
        root.lagosTime = data.lagos;
        root.sanFranciscoTime = data.sanfrancisco;
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.mediaStatus === "Playing" && root.mediaPlayer !== null
        onTriggered: {
            if (root.mediaPlayer !== null) {
                root.mediaPlayer.positionChanged();
            }
        }
    }

    PwObjectTracker {
        objects: [root.audioSink]
    }
}
