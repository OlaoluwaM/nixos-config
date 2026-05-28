import QtQuick

// Tiny label that appears near an item while it is hovered.
//
// The caller decides where to anchor it. This keeps tooltip wording and layout
// local to the feature, while the bubble styling stays consistent everywhere.
Rectangle {
    id: root

    property string text: ""
    property bool active: false

    visible: root.active && root.text.length > 0
    implicitWidth: tooltipText.implicitWidth + 16
    implicitHeight: tooltipText.implicitHeight + 8
    width: implicitWidth
    height: implicitHeight
    radius: 6
    color: Theme.surfaceVariant
    border.color: Theme.outline
    border.width: 1
    z: 10

    StyledText {
        id: tooltipText

        anchors.centerIn: parent
        text: root.text
        color: Theme.text
        font.pixelSize: 11
        textFormat: Text.PlainText
    }
}
