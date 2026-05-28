pragma ComponentBehavior: Bound

import QtQml

QtObject {
    id: root

    required property StatusController status

    // Media controls operate on the player selected by StatusController so the
    // bar, panel, and action API stay pointed at the same MPRIS source.
    readonly property var player: root.status.mediaPlayer

    function perform(action) {
        if (root.player === null) return;

        switch (action) {
            case "previous":
                if (root.player.canGoPrevious) root.player.previous();
                break;
            case "play-pause":
                if (root.player.canTogglePlaying) root.player.togglePlaying();
                break;
            case "next":
                if (root.player.canGoNext) root.player.next();
                break;
        }
    }
}
