import QtQuick

Item {
    id: root

    property alias text: label.text
    property alias color: label.color
    property alias font: label.font
    property int pauseDuration: 2000
    property real speed: 30

    clip: true
    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    readonly property real overflow: Math.max(0, label.implicitWidth - root.width)
    readonly property bool scrolling: overflow > 0 && root.width > 0

    StyledText {
        id: label
        y: 0

        SequentialAnimation on x {
            running: root.scrolling
            loops: Animation.Infinite

            NumberAnimation { to: 0; duration: 0 }
            PauseAnimation { duration: root.pauseDuration }
            NumberAnimation {
                to: -root.overflow
                duration: root.overflow / root.speed * 1000
                easing.type: Easing.Linear
            }
            PauseAnimation { duration: root.pauseDuration }
            NumberAnimation {
                to: 0
                duration: root.overflow / root.speed * 1000
                easing.type: Easing.Linear
            }
        }

        onTextChanged: x = 0
    }
}
