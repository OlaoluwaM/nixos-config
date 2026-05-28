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

        Rectangle {
            id: recordDisc
            width: 30
            height: 30
            anchors.verticalCenter: parent.verticalCenter
            radius: 15
            color: "#15161a"
            border.color: Theme.outline
            border.width: 1

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

                Image {
                    id: mediaArtwork
                    anchors.fill: parent
                    source: root.status.mediaAlbumArt
                    sourceSize.width: 24
                    sourceSize.height: 24
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }

                Shape {
                    anchors.fill: parent
                    visible: root.status.mediaAlbumArt.length > 0 && mediaArtwork.status === Image.Ready

                    ShapePath {
                        fillItem: mediaArtwork
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
                    visible: root.status.mediaAlbumArt.length === 0 || !(mediaArtwork.status === Image.Ready)
                    name: root.status.mediaStatus === "Playing" ? "play" : "music"
                    iconColor: Theme.text
                    implicitSize: 9
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 4
                height: 4
                radius: 2
                color: "#0b0c0f"
                opacity: root.status.mediaAlbumArt.length > 0 && mediaArtwork.status === Image.Ready ? 0.65 : 0
            }

            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 6000
                loops: Animation.Infinite
                running: root.visible && root.status.mediaStatus === "Playing"
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
                onTapped: root.popups.toggle("media")
            }
        }

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
                normalColor: Theme.surfaceVariant
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
                normalColor: Theme.surfaceVariant
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
                normalColor: Theme.surfaceVariant
                onClicked: root.mediaActions.perform("next")
            }
        }
    }
}
