pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// Calendar popover — month grid on the left, large clock on the right.
// Adjust popover card size in Popovers.qml if the grid is clipped.
Item {
    id: calPanel

    // Live clock — ticks every second for the big display
    property string hoursMinutes: "--:--"
    property string seconds: ":--"
    property string dateLine: "Loading"
    property int monthOffset: 0

    function calendarDate() {
        let now = new Date();
        return new Date(now.getFullYear(), now.getMonth() + calPanel.monthOffset, 1);
    }

    function calendarTitle() {
        let d = calPanel.calendarDate();
        let months = ["January","February","March","April","May","June",
                      "July","August","September","October","November","December"];
        return months[d.getMonth()] + " " + d.getFullYear();
    }

    function calendarDays() {
        let now = new Date();
        let target = calPanel.calendarDate();
        let year = target.getFullYear();
        let month = target.getMonth();
        let first = new Date(year, month, 1);
        let start = (first.getDay() + 6) % 7; // Monday = 0
        let daysInMonth = new Date(year, month + 1, 0).getDate();
        let daysInPrev = new Date(year, month, 0).getDate();
        let result = [];
        for (let i = 0; i < 42; i++) {
            let day = i - start + 1;
            let value = day;
            let current = true;
            if (day < 1) { value = daysInPrev + day; current = false; }
            else if (day > daysInMonth) { value = day - daysInMonth; current = false; }
            result.push({
                day: value,
                current: current,
                today: current && value === now.getDate() && month === now.getMonth() && year === now.getFullYear()
            });
        }
        return result;
    }

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
                        iconColor: hovered ? Theme.primaryForeground : Theme.textSecondary
                        iconSize: 13
                        onClicked: calPanel.monthOffset -= 1
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: calPanel.calendarTitle().toUpperCase()
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
                        iconColor: hovered ? Theme.primaryForeground : Theme.textSecondary
                        iconSize: 13
                        onClicked: calPanel.monthOffset += 1
                    }
                }

                Grid {
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: 7
                    rowSpacing: 4
                    columnSpacing: 2

                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                        delegate: StyledText {
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
                        model: calPanel.calendarDays()

                        delegate: Rectangle {
                            required property var modelData
                            width: 34
                            height: 30
                            radius: 8
                            color: modelData.today ? Theme.primary : "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: modelData.day
                                color: modelData.today   ? Theme.primaryForeground
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

                    StyledText {
                        id: bigTime
                        text: calPanel.hoursMinutes
                        color: Theme.text
                        font.pixelSize: 54
                        font.weight: Font.DemiBold
                    }

                    StyledText {
                        id: bigSec
                        text: calPanel.seconds
                        color: Theme.textSecondary
                        font.pixelSize: 22
                        anchors.left: bigTime.right
                        anchors.baseline: bigTime.baseline
                    }
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: calPanel.dateLine
                    color: Theme.textSecondary
                    font.pixelSize: 13
                }
            }
        }
    }
}
