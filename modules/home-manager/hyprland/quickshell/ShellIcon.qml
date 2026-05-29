import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

IconImage {
    required property string name
    // color (not string): callers pass Theme.* color tokens; iconSource()
    // serialises it to a hex string for the SVG stroke.
    property color iconColor: Theme.text

    implicitSize: 16
    width: implicitSize
    height: implicitSize
    Layout.preferredWidth: implicitSize
    Layout.preferredHeight: implicitSize
    Layout.alignment: Qt.AlignVCenter
    source: Icons.iconSource(name, iconColor)
    mipmap: true
}
