pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

BarCapsule {
    id: root
    required property StatusController status
    readonly property int statsSlotWidth: 46

    width: 188
    respondToHover: false

    RowLayout {
        anchors.centerIn: parent
        spacing: 6

        Item {
            Layout.preferredWidth: root.statsSlotWidth
            Layout.preferredHeight: cpuStatContent.implicitHeight

            RowLayout {
                id: cpuStatContent
                anchors.centerIn: parent
                spacing: 4

                ShellIcon { name: "cpu"; iconColor: Theme.metricCpu; implicitSize: Theme.barIconSize }
                StyledText {
                    text: root.status.cpuPercent + "%"
                    color: Theme.metricCpu
                    font.pixelSize: Theme.barFontBody
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
            Layout.preferredWidth: root.statsSlotWidth
            Layout.preferredHeight: memoryStatContent.implicitHeight

            RowLayout {
                id: memoryStatContent
                anchors.centerIn: parent
                spacing: 4

                ShellIcon { name: "memory"; iconColor: Theme.metricMemory; implicitSize: Theme.barIconSize }
                StyledText {
                    text: root.status.memPercent + "%"
                    color: Theme.metricMemory
                    font.pixelSize: Theme.barFontBody
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
            Layout.preferredWidth: root.statsSlotWidth
            Layout.preferredHeight: tempStatContent.implicitHeight

            RowLayout {
                id: tempStatContent
                anchors.centerIn: parent
                spacing: 4

                ShellIcon { name: "temp"; iconColor: Theme.metricTemperature; implicitSize: Theme.barIconSize }
                StyledText {
                    // tempC is null on machines without a CPU sensor (e.g. VMs).
                    text: root.status.tempC !== null ? root.status.tempC + "°C" : qsTr("N/A")
                    color: Theme.metricTemperature
                    font.pixelSize: Theme.barFontBody
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
