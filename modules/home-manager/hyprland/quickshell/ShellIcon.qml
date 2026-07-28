import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

IconImage {
    id: root

    required property string name
    // color (not string): callers pass Theme.* color tokens; iconSource()
    // serialises it to a hex string for the SVG stroke.
    property color iconColor: Theme.text

    implicitSize: 16
    width: root.implicitSize
    height: root.implicitSize
    Layout.preferredWidth: root.implicitSize
    Layout.preferredHeight: root.implicitSize
    Layout.alignment: Qt.AlignVCenter
    source: Icons.iconSource(root.name, root.iconColor)
    mipmap: true
}
