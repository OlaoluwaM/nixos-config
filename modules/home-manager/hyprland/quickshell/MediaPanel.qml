pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// Media popover — a hero album-art column on the left; metadata, progress, and
// transport controls grouped beside it; a player switcher (when more than one
// source is active) spans the width below.
ColumnLayout {
    id: panel
    required property var mediaActions
    required property var status
    spacing: 0

    // Crossfade the art + metadata when the active source changes, so switching
    // players dissolves rather than snapping. Keyed on the source identity, so
    // ordinary track changes within one player don't trigger it. Gated until
    // after creation so the fade plays only on real switches, not on open.
    property bool sourceFadeReady: false
    readonly property string activeSource: panel.status.mediaSource
    onActiveSourceChanged: if (panel.sourceFadeReady) sourceFade.restart()
    Component.onCompleted: panel.sourceFadeReady = true

    OpacityAnimator {
        id: sourceFade
        target: mediaRow
        from: 0
        to: 1
        duration: Theme.animFade
        easing.type: Theme.easingType
        easing.bezierCurve: Theme.easingDecel
    }

    // The card sizes itself to this content (see Popovers.qml), so these
    // spacers only matter as a fallback — they keep the content centred if the
    // card is ever taller than its contents.
    Item { Layout.fillHeight: true }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 35

        // ── Hero art + control column ────────────────────────────────────
        RowLayout {
            id: mediaRow
            Layout.fillWidth: true
            spacing: 18

            // Square art sized to the control column's height, so its bottom
            // edge lines up with the transport row and its top with the kicker.
            // Bound to the column's implicitHeight (its intrinsic content height),
            // not its laid-out height — the latter is partly driven by this art
            // via the row, which would be a binding loop.
            Rectangle {
                Layout.preferredWidth: controlColumn.implicitHeight
                Layout.preferredHeight: controlColumn.implicitHeight
                Layout.alignment: Qt.AlignTop
                radius: Theme.cardRadius
                color: Theme.surfaceDeep
                border.color: Theme.outline
                border.width: 1
                clip: true

                readonly property bool hasArtwork: panel.status.mediaAlbumArt.length > 0
                    && panelArt.status === Image.Ready

                Image {
                    id: panelArt
                    anchors.fill: parent
                    source: panel.status.mediaAlbumArt
                    sourceSize.width: 160
                    sourceSize.height: 160
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: parent.hasArtwork
                }

                ShellIcon {
                    anchors.centerIn: parent
                    visible: !parent.hasArtwork
                    name: panel.status.mediaIsMusic ? "music" : "play"
                    iconColor: Theme.textDim
                    implicitSize: 42
                }
            }

            ColumnLayout {
                id: controlColumn
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    visible: panel.status.mediaSource.length > 0
                    text: panel.status.mediaSource.toUpperCase()
                    color: Theme.textDim
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                    elide: Text.ElideRight
                }

                MarqueeText {
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    text: panel.status.mediaTrackTitle
                    color: Theme.text
                    font.pixelSize: Theme.fontHeader
                    font.weight: Font.DemiBold
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: panel.status.mediaArtist.length > 0
                    text: panel.status.mediaArtist
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontBody
                    elide: Text.ElideRight
                }

                Item { Layout.preferredHeight: 8 }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 3
                    radius: height / 2
                    color: Theme.surfaceVariant
                    // Hidden when the player reports no duration; an empty bar
                    // would imply a zero-length track. Elapsed time still shows.
                    visible: panel.status.mediaHasLength

                    // Progress fill. The width animates so the once-a-second
                    // position ticks (see MediaStatus' poke timer) glide instead
                    // of stepping; seeks also slide rather than jump.
                    Rectangle {
                        width: parent.width * panel.status.mediaProgress
                        height: parent.height
                        radius: parent.radius
                        color: Theme.primary

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.animFast
                                easing.type: Theme.easingType
                                easing.bezierCurve: Theme.easingCurve
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        text: panel.status.mediaPosition
                        color: Theme.textDim
                        font.family: Theme.monoFontFamily
                        font.pixelSize: Theme.fontSmall
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        // Hidden alongside the bar when the player gives no length.
                        visible: panel.status.mediaHasLength
                        text: panel.status.mediaLength
                        color: Theme.textDim
                        font.family: Theme.monoFontFamily
                        font.pixelSize: Theme.fontSmall
                    }
                }

                Item { Layout.preferredHeight: 6 }

                // ── Transport controls ──────────────────────────────────
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 14

                    IconButton {
                        accessibleName: qsTr("Previous")
                        buttonSize: 38
                        iconName: "previous"
                        iconSize: 16
                        onClicked: panel.mediaActions.perform("previous")
                    }

                    IconButton {
                        accessibleName: qsTr("Play or pause")
                        active: true
                        buttonSize: 44
                        iconName: panel.status.mediaStatus === "Playing" ? "pause" : "play"
                        iconSize: 18
                        onClicked: panel.mediaActions.perform("play-pause")
                    }

                    IconButton {
                        accessibleName: qsTr("Next")
                        buttonSize: 38
                        iconName: "next"
                        iconSize: 16
                        onClicked: panel.mediaActions.perform("next")
                    }
                }
            }
        }

        // ── Player switcher — only when more than one MPRIS source is active ─
        // Setting selectedPlayerId pins the bar/panel; "" falls back to auto-pick.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4
            visible: panel.status.mediaPlayers.length > 1

            Repeater {
                model: panel.status.mediaPlayers

                delegate: Rectangle {
                    id: segment
                    required property var modelData

                    readonly property bool current: panel.status.mediaPlayer !== null
                        && modelData.dbusName === panel.status.mediaPlayer.dbusName

                    implicitWidth: segmentLabel.implicitWidth + 24
                    implicitHeight: 28
                    radius: Theme.capsuleButtonRadius
                    color: segment.current ? Theme.surfaceVariant
                        : segmentMouse.containsMouse ? Theme.surfaceHover
                        : "transparent"
                    activeFocusOnTab: true

                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Switch to %1").arg(modelData.identity || qsTr("player"))

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animFast
                            easing.type: Theme.easingType
                            easing.bezierCurve: Theme.easingCurve
                        }
                    }

                    StyledText {
                        id: segmentLabel
                        anchors.centerIn: parent
                        text: segment.modelData.identity || qsTr("Unknown")
                        color: segment.current ? Theme.primary : Theme.textDim
                        font.pixelSize: Theme.fontCaption
                        font.weight: segment.current ? Font.DemiBold : Font.Normal

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.animFast
                                easing.type: Theme.easingType
                                easing.bezierCurve: Theme.easingCurve
                            }
                        }
                    }

                    MouseArea {
                        id: segmentMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: panel.status.selectedPlayerId = segment.modelData.dbusName
                    }
                }
            }
        }
    }

    Item { Layout.fillHeight: true }
}
