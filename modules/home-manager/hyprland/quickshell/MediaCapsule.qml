pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

BarCapsule {
    id: root
    required property MediaActions mediaActions
    required property PopupController popups
    required property StatusController status

    visible: root.status.mediaActive
    width: root.status.mediaActive ? 280 : 0
    active: root.popups.activePopup === "media"
    clipped: true

    Row {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // Leading visual: a spinning vinyl record for music; a static rounded
        // thumbnail (or glyph) for everything else — video, podcasts, browsers.
        Item {
            id: mediaThumb
            width: 30
            height: 30
            anchors.verticalCenter: parent.verticalCenter

            // ── Music: spinning vinyl record ─────────────────────────────
            Rectangle {
                id: recordDisc
                anchors.fill: parent
                radius: width / 2
                visible: root.status.mediaIsMusic
                color: Theme.surfaceDeep
                border.color: Theme.outline
                border.width: 1

                readonly property bool hasArtwork: root.status.mediaAlbumArt.length > 0
                    && discArt.status === Image.Ready

                // Hidden source image; the Shape below clips it into a circle.
                Image {
                    id: discArt
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    source: root.status.mediaAlbumArt
                    sourceSize.width: 28
                    sourceSize.height: 28
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }

                // groove ring
                Rectangle {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    radius: 11
                    color: "transparent"
                    border.color: Theme.surfaceHover
                    border.width: 1
                    opacity: 0.55
                }

                Item {
                    id: artworkLens
                    anchors.centerIn: parent
                    width: 14
                    height: 14

                    Shape {
                        anchors.fill: parent
                        visible: recordDisc.hasArtwork

                        ShapePath {
                            fillItem: discArt
                            strokeWidth: -1
                            startX: artworkLens.width
                            startY: artworkLens.height / 2

                            PathAngleArc {
                                centerX: artworkLens.width / 2
                                centerY: artworkLens.height / 2
                                radiusX: artworkLens.width / 2
                                radiusY: artworkLens.height / 2
                                startAngle: 0
                                sweepAngle: 360
                            }
                        }
                    }

                    ShellIcon {
                        anchors.centerIn: parent
                        visible: !recordDisc.hasArtwork
                        name: root.status.mediaStatus === "Playing" ? "play" : "music"
                        iconColor: Theme.text
                        implicitSize: 9
                    }
                }

                // spindle hole
                Rectangle {
                    anchors.centerIn: parent
                    width: 4
                    height: 4
                    radius: 2
                    color: Theme.surfaceDeep
                    opacity: recordDisc.hasArtwork ? 0.65 : 0
                }

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 6000
                    loops: Animation.Infinite
                    running: recordDisc.visible && root.status.mediaStatus === "Playing"
                }
            }

            // ── Non-music: static rounded thumbnail / glyph ──────────────
            Rectangle {
                id: thumbCard
                anchors.fill: parent
                visible: !root.status.mediaIsMusic
                radius: Theme.capsuleButtonRadius
                color: Theme.surfaceDeep
                border.color: Theme.outline
                border.width: 1
                clip: true

                readonly property bool hasArtwork: root.status.mediaAlbumArt.length > 0
                    && thumbArt.status === Image.Ready

                Image {
                    id: thumbArt
                    anchors.fill: parent
                    source: root.status.mediaAlbumArt
                    sourceSize.width: 30
                    sourceSize.height: 30
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: thumbCard.hasArtwork
                }

                ShellIcon {
                    anchors.centerIn: parent
                    visible: !thumbCard.hasArtwork
                    name: root.status.mediaStatus === "Playing" ? "play" : "music"
                    iconColor: Theme.text
                    implicitSize: 14
                }
            }
        }

        Item {
            width: 120
            height: 30

            Column {
                anchors.fill: parent
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                MarqueeText {
                    width: parent.width
                    height: implicitHeight
                    text: root.status.mediaDisplayTitle
                    color: Theme.capsuleTextColor(root.popups.activePopup === "media", root.hovered)
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                StyledText {
                    width: parent.width
                    text: root.status.mediaPosition + " / " + root.status.mediaLength
                    color: Theme.capsuleTextColor(root.popups.activePopup === "media", root.hovered)
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    textFormat: Text.PlainText
                }
            }

            TapHandler {
                onTapped: root.popups.toggleAt("media", root.mapToItem(null, root.width / 2, 0).x)
            }
        }

        // Inline transport. These sit on top of the capsule's own fill, so the
        // buttons stay chromeless — transparent at rest and on hover — and only
        // the icon brightens. A filled hover box here would read as a panel
        // inside the capsule, which looked busy against the popup's flat icons.
        Row {
            width: 98
            height: 30
            spacing: 4

            IconButton {
                accessibleName: qsTr("Previous")
                buttonSize: 30
                width: implicitWidth
                height: implicitHeight
                iconName: "previous"
                iconSize: 15
                iconColor: hovered ? Theme.text
                    : Theme.capsuleTextColor(root.popups.activePopup === "media", root.hovered)
                normalColor: "transparent"
                hoverColor: "transparent"
                onClicked: root.mediaActions.perform("previous")
            }

            IconButton {
                accessibleName: qsTr("Play or pause")
                buttonSize: 30
                width: implicitWidth
                height: implicitHeight
                iconName: root.status.mediaStatus === "Playing" ? "pause" : "play"
                iconSize: 15
                iconColor: hovered ? Theme.text
                    : Theme.capsuleTextColor(root.popups.activePopup === "media", root.hovered)
                normalColor: "transparent"
                hoverColor: "transparent"
                onClicked: root.mediaActions.perform("play-pause")
            }

            IconButton {
                accessibleName: qsTr("Next")
                buttonSize: 30
                width: implicitWidth
                height: implicitHeight
                iconName: "next"
                iconSize: 15
                iconColor: hovered ? Theme.text
                    : Theme.capsuleTextColor(root.popups.activePopup === "media", root.hovered)
                normalColor: "transparent"
                hoverColor: "transparent"
                onClicked: root.mediaActions.perform("next")
            }
        }
    }
}
