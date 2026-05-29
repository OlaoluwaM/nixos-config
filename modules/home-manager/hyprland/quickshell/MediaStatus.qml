pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Services.Mpris

Scope {
    id: root

    readonly property var mediaPlayers: Mpris.players.values

    // A user pick (by dbusName) wins while that player still exists; otherwise
    // we fall back to auto-selecting the most relevant player.
    property string selectedPlayerId: ""
    readonly property var mediaPlayer: root.pickMediaPlayer(root.mediaPlayers, root.selectedPlayerId)

    readonly property string mediaStatus: root.mediaPlaybackStatus(root.mediaPlayer)
    readonly property string mediaSource: root.mediaPlayer !== null ? root.mediaPlayer.identity : ""
    readonly property string mediaArtist: root.mediaPlayer !== null ? root.mediaPlayer.trackArtist : ""
    readonly property string mediaAlbum: root.mediaPlayer !== null ? root.mediaPlayer.trackAlbum : ""
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
    readonly property real mediaProgress: (root.mediaPlayer !== null && root.mediaPlayer.length > 0)
        ? Math.max(0, Math.min(1, root.mediaPlayer.position / root.mediaPlayer.length))
        : 0
    // Whether the player advertises a track length. Some players (notably
    // G4Music / "Gapless") publish mpris:length as 0 — i.e. no duration — so the
    // UI hides the progress bar and total and shows only the elapsed position.
    readonly property bool mediaHasLength: root.mediaPlayer !== null && root.mediaPlayer.length > 0
    // A player the user explicitly pinned is honoured even while stopped, so
    // switching to an open-but-idle source (e.g. Spotify) keeps it on the bar.
    readonly property bool hasExplicitSelection: root.mediaPlayer !== null
        && root.selectedPlayerId.length > 0
        && root.mediaPlayer.dbusName === root.selectedPlayerId
    readonly property bool mediaActive: root.mediaStatus === "Playing"
        || root.mediaStatus === "Paused"
        || root.hasExplicitSelection
    // Heuristic: a track with an album is "music" (Spotify, local players, …);
    // browser video (YouTube, etc.) reports no album. Drives the vinyl visual.
    readonly property bool mediaIsMusic: root.mediaPlayer !== null && root.mediaAlbum.length > 0
    readonly property string mediaDisplayTitle:
        root.mediaArtist.length > 0 && root.mediaTrackTitle.length > 0
            ? root.mediaArtist + " — " + root.mediaTrackTitle
            : root.mediaTrackTitle

    function pickMediaPlayer(players, selectedId) {
        if (selectedId.length > 0) {
            for (let s = 0; s < players.length; s++) {
                if (players[s].dbusName === selectedId) return players[s];
            }
        }
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

    // H:MM:SS once a track crosses the hour mark (long mixes, podcasts, DJ sets),
    // otherwise the compact M:SS. Minutes are only zero-padded when hours are
    // shown, so short tracks read "3:07" rather than "03:07".
    function formatDuration(seconds) {
        let total = Math.max(0, Math.floor(Number(seconds) || 0));
        let s = String(total % 60).padStart(2, "0");
        let m = Math.floor(total / 60) % 60;
        let h = Math.floor(total / 3600);
        return h > 0
            ? h + ":" + String(m).padStart(2, "0") + ":" + s
            : m + ":" + s;
    }

    // MPRIS reports position on seek, not continuously, so a playing track's
    // position would otherwise look frozen. Re-emit positionChanged once a second
    // while playing to drive the progress bar and timestamp forward; the value
    // itself is read live from the player, this only nudges bindings to refresh.
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
