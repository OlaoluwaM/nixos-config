pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// Media popover content — larger view of now-playing info and controls.
ColumnLayout {
    required property var shell
    spacing: 14

    Text {
        text: shell.mediaDisplayTitle
        color: Theme.text
        font.pixelSize: 16
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        Layout.fillWidth: true
    }

    Text {
        text: shell.mediaStatus + " — " + shell.mediaPosition + " / " + shell.mediaLength
        color: Theme.textSecondary
        font.pixelSize: 12
    }

    RowLayout {
        spacing: 10

        Repeater {
            model: [
                { label: "Prev",  action: "previous"   },
                { label: "Play",  action: "play-pause"  },
                { label: "Next",  action: "next"        }
            ]

            delegate: ActionButton {
                required property var modelData

                label: modelData.label
                filled: false
                accessibleName: modelData.label
                Layout.preferredWidth: 72
                Layout.preferredHeight: 34
                buttonHeight: 34
                onClicked: shell.runPlayerctl(modelData.action)
            }
        }
    }
}
