pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

ColumnLayout {
    id: trayPanel
    required property var popups
    spacing: 16

    property var activeMenuSource: null
    property real gridOpacity: 1
    property real menuOpacity: 0

    function updateMenuContentHeight() {
        if (trayPanel.activeMenuSource) {
            trayPanel.popups.trayMenuContentHeight = Math.ceil(headerRow.implicitHeight + trayPanel.spacing + menuColumn.implicitHeight);
        }
    }

    onActiveMenuSourceChanged: {
        if (activeMenuSource) {
            openMenuAnim.stop();
            closeMenuAnim.stop();
            openMenuAnim.start();
            Qt.callLater(updateMenuContentHeight);
        } else {
            openMenuAnim.stop();
            closeMenuAnim.stop();
            closeMenuAnim.start();
        }
    }

    SequentialAnimation {
        id: openMenuAnim
        ParallelAnimation {
            NumberAnimation { target: trayPanel; property: "gridOpacity"; to: 0; duration: 100; easing.type: Easing.InQuad }
            NumberAnimation { target: trayPanel; property: "menuOpacity"; to: 1; duration: 140; easing.type: Easing.OutQuad }
        }
    }

    SequentialAnimation {
        id: closeMenuAnim
        ScriptAction {
            script: trayPanel.popups.trayMenuContentHeight = 0
        }
        PauseAnimation { duration: 60 }
        ParallelAnimation {
            NumberAnimation { target: trayPanel; property: "menuOpacity"; to: 0; duration: 100; easing.type: Easing.InQuad }
            NumberAnimation { target: trayPanel; property: "gridOpacity"; to: 1; duration: 140; easing.type: Easing.OutQuad }
        }
    }

    QsMenuOpener {
        id: menuOpener
        menu: trayPanel.activeMenuSource ? trayPanel.activeMenuSource.menu : null
    }

    function cleanTrayName(source) {
        let name = source.id || source.tooltipTitle || source.title || "Menu";
        name = name.replace(/[-_]/g, " ").replace(/\s+/g, " ").trim();
        return name.replace(/\b\w/g, function(c) { return c.toUpperCase(); });
    }

    RowLayout {
        id: headerRow
        Layout.fillWidth: true
        spacing: 10

        IconButton {
            visible: trayPanel.activeMenuSource !== null
            accessibleName: qsTr("Back")
            iconName: "left"
            iconSize: 13
            normalColor: "transparent"
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignVCenter
            buttonSize: 32
            onClicked: trayPanel.activeMenuSource = null
        }

        StyledText {
            text: trayPanel.activeMenuSource
                ? trayPanel.cleanTrayName(trayPanel.activeMenuSource)
                : "System Tray"
            color: Theme.text
            font.pixelSize: 16
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        Flickable {
            id: trayGridView
            anchors.fill: parent
            opacity: trayPanel.gridOpacity
            visible: opacity > 0
            contentWidth: width
            contentHeight: trayGrid.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            GridLayout {
                id: trayGrid
                columns: 4
                rowSpacing: 14
                columnSpacing: 14

                Repeater {
                    model: SystemTray.items

                    delegate: Rectangle {
                        id: trayDelegate
                        required property var modelData

                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 56
                        radius: 12
                        color: trayItemMouse.containsMouse ? Theme.surfaceVariant : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Easing.InOutQuad } }

                        Image {
                            id: trayIcon
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            source: trayDelegate.modelData.icon
                            sourceSize.width: 20
                            sourceSize.height: 20
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            visible: status === Image.Ready
                        }

                        StyledText {
                            anchors.centerIn: parent
                            visible: trayIcon.status !== Image.Ready
                            text: (trayDelegate.modelData.title || trayDelegate.modelData.id || "?").slice(0, 1).toUpperCase()
                            color: trayItemMouse.containsMouse ? Theme.text : Theme.textSecondary
                            font.pixelSize: 16
                            font.weight: Font.DemiBold

                            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Easing.InOutQuad } }
                        }

                        MouseArea {
                            id: trayItemMouse
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            hoverEnabled: true
                            onClicked: function(mouse) {
                                if (trayDelegate.modelData.hasMenu) {
                                    trayPanel.activeMenuSource = trayDelegate.modelData;
                                } else {
                                    trayDelegate.modelData.activate();
                                }
                            }
                        }

                        HoverTooltip {
                            active: trayItemMouse.containsMouse
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.top
                            anchors.bottomMargin: 6
                            text: trayDelegate.modelData.tooltipTitle || trayDelegate.modelData.title || trayDelegate.modelData.id || qsTr("App")
                        }
                    }
                }
            }
        }

        Flickable {
            id: menuView
            anchors.fill: parent
            opacity: trayPanel.menuOpacity
            visible: opacity > 0
            contentWidth: width
            contentHeight: menuColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: menuColumn
                width: menuView.width
                spacing: 2
                onImplicitHeightChanged: trayPanel.updateMenuContentHeight()

                Repeater {
                    model: menuOpener.children

                    delegate: Item {
                        id: menuEntry
                        required property var modelData
                        required property int index

                        width: menuColumn.width
                        height: modelData.isSeparator ? 9 : 36
                        visible: !modelData.hasChildren

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: !menuEntry.modelData.isSeparator && menuEntryMouse.containsMouse
                                ? Theme.surfaceVariant : "transparent"
                            visible: !menuEntry.modelData.isSeparator

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Image {
                                    visible: menuEntry.modelData.icon !== ""
                                    source: menuEntry.modelData.icon
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    sourceSize.width: 16
                                    sourceSize.height: 16
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }

                                StyledText {
                                    text: menuEntry.modelData.text || ""
                                    color: menuEntry.modelData.enabled ? Theme.text : Theme.textSecondary
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    visible: menuEntry.modelData.checkState === Qt.Checked
                                    text: "✓"
                                    color: Theme.primary
                                    font.pixelSize: 14
                                }
                            }

                            MouseArea {
                                id: menuEntryMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: menuEntry.modelData.enabled
                                onClicked: {
                                    menuEntry.modelData.triggered();
                                    trayPanel.activeMenuSource = null;
                                }
                            }
                        }

                        Rectangle {
                            visible: menuEntry.modelData.isSeparator
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 1
                            color: Theme.outline
                        }
                    }
                }
            }
        }
    }
}
