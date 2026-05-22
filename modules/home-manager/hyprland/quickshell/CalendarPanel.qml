pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// Calendar popover — month grid on the left, large clock on the right.
// Adjust popover card size in Popovers.qml if the grid is clipped.
Item {
    id: calPanel
    required property var shell

    // Live clock — ticks every second for the big display
    property string hoursMinutes: "--:--"
    property string seconds: ":--"
    property string dateLine: "Loading"

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let now = new Date();
            let h = now.getHours();
            let m = now.getMinutes();
            let s = now.getSeconds();
            calPanel.hoursMinutes = (h < 10 ? "0" + h : h) + ":" + (m < 10 ? "0" + m : m);
            calPanel.seconds = ":" + (s < 10 ? "0" + s : s);
            let days = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"];
            let months = ["January","February","March","April","May","June",
                          "July","August","September","October","November","December"];
            calPanel.dateLine = days[now.getDay()] + ", " + months[now.getMonth()] + " " + now.getDate();
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 24

        // ── Left: Calendar ────────────────────────────────────────────
        Item {
            Layout.preferredWidth: 340
            Layout.fillHeight: true

            Column {
                anchors.centerIn: parent
                spacing: 18

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    IconButton {
                        accessibleName: qsTr("Previous month")
                        buttonSize: 28
                        width: implicitWidth
                        height: implicitHeight
                        hoverColor: Theme.primary
                        iconName: "left"
                        iconColor: hovered ? Theme.primaryContrast : Theme.textSecondary
                        iconSize: 13
                        onClicked: calPanel.shell.calendarMonthOffset -= 1
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: calPanel.shell.calendarTitle().toUpperCase()
                        color: Theme.text
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }

                    IconButton {
                        accessibleName: qsTr("Next month")
                        buttonSize: 28
                        width: implicitWidth
                        height: implicitHeight
                        hoverColor: Theme.primary
                        iconName: "right"
                        iconColor: hovered ? Theme.primaryContrast : Theme.textSecondary
                        iconSize: 13
                        onClicked: calPanel.shell.calendarMonthOffset += 1
                    }
                }

                Grid {
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: 7
                    rowSpacing: 4
                    columnSpacing: 2

                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                        delegate: Text {
                            required property string modelData
                            width: 34
                            height: 18
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: Theme.textDim
                            font.pixelSize: 11
                        }
                    }

                    Repeater {
                        model: calPanel.shell.calendarDays()

                        delegate: Rectangle {
                            required property var modelData
                            width: 34
                            height: 30
                            radius: 8
                            color: modelData.today ? Theme.primary : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                color: modelData.today   ? Theme.primaryContrast
                                     : modelData.current ? Theme.text
                                     : Theme.textDim
                                font.pixelSize: 12
                                font.weight: modelData.today ? Font.DemiBold : Font.Normal
                            }
                        }
                    }
                }
            }
        }

        // ── Divider ───────────────────────────────────────────────────
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: Theme.outline
        }

        // ── Right: Big clock ──────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Column {
                anchors.centerIn: parent
                spacing: 8

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: bigTime.implicitWidth + bigSec.implicitWidth
                    height: bigTime.implicitHeight

                    Text {
                        id: bigTime
                        text: calPanel.hoursMinutes
                        color: Theme.text
                        font.pixelSize: 54
                        font.weight: Font.DemiBold
                    }

                    Text {
                        id: bigSec
                        text: calPanel.seconds
                        color: Theme.textSecondary
                        font.pixelSize: 22
                        anchors.left: bigTime.right
                        anchors.baseline: bigTime.baseline
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: calPanel.dateLine
                    color: Theme.textSecondary
                    font.pixelSize: 13
                }
            }
        }
    }
}
