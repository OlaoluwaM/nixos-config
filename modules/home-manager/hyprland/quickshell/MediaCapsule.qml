pragma ComponentBehavior: Bound

import QtQuick

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
            width: 30
            height: Theme.capsuleButtonSize
            radius: Theme.capsuleButtonRadius
            color: Theme.outline
            clip: true

            Image {
                id: mediaArtwork
                anchors.fill: parent
                source: root.status.mediaAlbumArt
                sourceSize.width: 30
                sourceSize.height: 30
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: root.status.mediaAlbumArt.length > 0 && mediaArtwork.status === Image.Ready
            }

            ShellIcon {
                anchors.centerIn: parent
                visible: root.status.mediaAlbumArt.length === 0 || !(mediaArtwork.status === Image.Ready)
                name: root.status.mediaStatus === "Playing" ? "play" : "music"
                iconColor: Theme.text
                implicitSize: 16
            }
        }

        Item {
            width: 132
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

                Text {
                    width: parent.width
                    text: root.status.mediaPosition + " / " + root.status.mediaLength
                    color: Theme.capsuleTextColor(root.popups.activePopup === "media", root.hovered)
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    textFormat: Text.PlainText
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.popups.toggle("media")
            }
        }

        Row {
            width: 74
            height: 30
            spacing: 4

            IconButton {
                accessibleName: qsTr("Previous")
                buttonWidth: 22
                buttonHeight: Theme.capsuleButtonSize
                width: implicitWidth
                height: implicitHeight
                iconName: "previous"
                iconSize: 15
                iconColor: hovered ? Theme.tertiaryContrast
                    : Theme.capsuleTextColor(root.popups.activePopup === "media", root.hovered)
                normalColor: "transparent"
                onClicked: root.mediaActions.perform("previous")
            }

            IconButton {
                accessibleName: qsTr("Play or pause")
                buttonWidth: 22
                buttonHeight: Theme.capsuleButtonSize
                width: implicitWidth
                height: implicitHeight
                iconName: root.status.mediaStatus === "Playing" ? "pause" : "play"
                iconSize: 15
                iconColor: hovered ? Theme.tertiaryContrast
                    : Theme.capsuleTextColor(root.popups.activePopup === "media", root.hovered)
                normalColor: "transparent"
                onClicked: root.mediaActions.perform("play-pause")
            }

            IconButton {
                accessibleName: qsTr("Next")
                buttonWidth: 22
                buttonHeight: Theme.capsuleButtonSize
                width: implicitWidth
                height: implicitHeight
                iconName: "next"
                iconSize: 15
                iconColor: hovered ? Theme.tertiaryContrast
                    : Theme.capsuleTextColor(root.popups.activePopup === "media", root.hovered)
                normalColor: "transparent"
                onClicked: root.mediaActions.perform("next")
            }
        }
    }
}
