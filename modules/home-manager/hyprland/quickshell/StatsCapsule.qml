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

                ShellIcon { name: "cpu"; iconColor: Theme.metricCpu; implicitSize: 16 }
                StyledText {
                    text: root.status.cpuPercent + "%"
                    color: Theme.metricCpu
                    font.pixelSize: 13
                }
            }

            HoverHandler {
                id: cpuHover
            }

            HoverTooltip {
                active: cpuHover.hovered
                text: qsTr("CPU: %1%").arg(root.status.cpuPercent)
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

                ShellIcon { name: "memory"; iconColor: Theme.metricMemory; implicitSize: 16 }
                StyledText {
                    text: root.status.memPercent + "%"
                    color: Theme.metricMemory
                    font.pixelSize: 13
                }
            }

            HoverHandler {
                id: memoryHover
            }

            HoverTooltip {
                active: memoryHover.hovered
                text: qsTr("Memory: %1%").arg(root.status.memPercent)
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

                ShellIcon { name: "temp"; iconColor: Theme.metricTemperature; implicitSize: 16 }
                StyledText {
                    // tempC is null on machines without a CPU sensor (e.g. VMs).
                    text: root.status.tempC !== null ? root.status.tempC + "°C" : qsTr("N/A")
                    color: Theme.metricTemperature
                    font.pixelSize: 13
                }
            }

            HoverHandler {
                id: tempHover
            }

            HoverTooltip {
                active: tempHover.hovered
                text: qsTr("Temperature: %1").arg(root.status.tempC !== null ? root.status.tempC + "°C" : qsTr("N/A"))
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.bottom
                    topMargin: 8
                }
            }
        }
    }
}
