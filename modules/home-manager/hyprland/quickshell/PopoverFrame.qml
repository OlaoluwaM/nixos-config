import QtQuick
import QtQuick.Effects

// Consumer-sized to avoid childrenRect and implicit-size feedback loops.
Item {
    id: root

    property alias contentItem: contentHost
    property int contentPadding: Theme.popoverPadding

    RectangularShadow {
        anchors.fill: surface
        radius: surface.radius
        color: Theme.popoverShadowColor
        blur: Theme.popoverShadowBlur
        offset.y: Theme.popoverShadowOffsetY
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: Theme.popoverFrameRadius
        color: Theme.base
        border.width: 0

        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: contentHost
            anchors.fill: parent
            anchors.margins: root.contentPadding
        }
    }
}
