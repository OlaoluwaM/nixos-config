import QtQuick

// A layout container that keeps related top-bar controls together inside the
// shared rail. The capsules own their fills, so groups do not create another
// nested surface around them.
Item {
    id: root

    default property alias content: contentHost.data

    implicitHeight: Theme.barControlHeight + Theme.barGroupPadding * 2
    height: implicitHeight

    Item {
        id: contentHost
        anchors.fill: parent
    }
}
