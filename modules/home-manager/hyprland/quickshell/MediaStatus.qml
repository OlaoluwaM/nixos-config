pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Services.Mpris

Scope {
    id: root

    readonly property var mediaPlayers: Mpris.players.values
    readonly property var mediaPlayer: root.pickMediaPlayer(root.mediaPlayers)
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
    readonly property bool mediaActive: root.mediaStatus === "Playing" || root.mediaStatus === "Paused"
    readonly property string mediaDisplayTitle:
        root.mediaArtist.length > 0 && root.mediaTrackTitle.length > 0
            ? root.mediaArtist + " — " + root.mediaTrackTitle
            : root.mediaTrackTitle

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
}
