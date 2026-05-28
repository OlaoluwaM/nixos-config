pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

BarCapsule {
    id: root
    required property StatusController status
    readonly property int statsSlotWidth: 54

    width: 250
    respondToHover: false

    RowLayout {
        id: statsRow
        anchors.centerIn: parent
        spacing: 10

        Item {
            id: cpuStat
            Layout.preferredWidth: root.statsSlotWidth
            Layout.preferredHeight: cpuStatContent.implicitHeight

            RowLayout {
                id: cpuStatContent
                anchors.centerIn: parent
                spacing: 5

                ShellIcon { name: "cpu"; iconColor: Theme.statsCpu; implicitSize: 16 }
                Text {
                    text: root.status.cpuText
                    color: Theme.statsCpu
                    font.pixelSize: 13
                }
            }

            HoverHandler {
                id: cpuHover
            }

            HoverTooltip {
                active: cpuHover.hovered
                text: qsTr("CPU: %1").arg(root.status.cpuText)
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.bottom
                    topMargin: 8
                }
            }
        }

        Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 16; color: Theme.outline }

        Item {
            id: memoryStat
            Layout.preferredWidth: root.statsSlotWidth
            Layout.preferredHeight: memoryStatContent.implicitHeight

            RowLayout {
                id: memoryStatContent
                anchors.centerIn: parent
                spacing: 5

                ShellIcon { name: "memory"; iconColor: Theme.statsMem; implicitSize: 16 }
                Text {
                    text: root.status.memText
                    color: Theme.statsMem
                    font.pixelSize: 13
                }
            }

            HoverHandler {
                id: memoryHover
            }

            HoverTooltip {
                active: memoryHover.hovered
                text: qsTr("Memory: %1").arg(root.status.memText)
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.bottom
                    topMargin: 8
                }
            }
        }

        Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 16; color: Theme.outline }

        Item {
            id: tempStat
            Layout.preferredWidth: root.statsSlotWidth
            Layout.preferredHeight: tempStatContent.implicitHeight

            RowLayout {
                id: tempStatContent
                anchors.centerIn: parent
                spacing: 5

                ShellIcon { name: "temp"; iconColor: Theme.statsTemp; implicitSize: 16 }
                Text {
                    text: root.status.tempText
                    color: Theme.statsTemp
                    font.pixelSize: 13
                }
            }

            HoverHandler {
                id: tempHover
            }

            HoverTooltip {
                active: tempHover.hovered
                text: qsTr("Temperature: %1").arg(root.status.tempText)
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.bottom
                    topMargin: 8
                }
            }
        }
    }
}
