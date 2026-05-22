import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

IconImage {
    required property string name
    property string iconColor: Theme.text

    implicitSize: 16
    width: implicitSize
    height: implicitSize
    Layout.preferredWidth: implicitSize
    Layout.preferredHeight: implicitSize
    Layout.alignment: Qt.AlignVCenter
    source: Icons.iconSource(name, iconColor)
    mipmap: true
}
