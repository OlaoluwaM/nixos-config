import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray

Scope {
    id: root

    property string activePopup: ""
    property bool doNotDisturb: false
    property bool trayButtonHovered: false
    property bool trayPopoverHovered: false
    property bool trayPinned: false
    property string clockText: "--"
    property string cpuText: "--"
    property string memText: "--"
    property string tempText: "--"
    property string powerProfileText: "--"
    property string batteryText: "--"
    property string networkText: "--"
    property string vpnText: "--"
    property string bluetoothText: "--"
    property string mediaStatus: "Stopped"
    property string mediaTitle: "No media"
    property string localTime: "--"
    property string birminghamTime: "--"
    property string lagosTime: "--"
    property string sanFranciscoTime: "--"

    function togglePopup(name) {
        if (name !== "tray") {
            trayPinned = false;
        }
        activePopup = activePopup === name ? "" : name;
    }

    function openTrayPopup(pinned) {
        if (SystemTray.items.count === 0) {
            return;
        }

        trayPinned = pinned;
        activePopup = "tray";
        trayCloseTimer.stop();
    }

    function scheduleTrayClose() {
        if (activePopup === "tray" && !trayPinned) {
            trayCloseTimer.restart();
        }
    }

    function maybeCloseTrayPopup() {
        if (activePopup === "tray" && !trayPinned && !trayButtonHovered && !trayPopoverHovered) {
            activePopup = "";
        }
    }

    function run(command) {
        Quickshell.execDetached(["sh", "-c", command]);
    }

    function refreshStatusSoon() {
        statusRefreshTimer.restart();
    }

    function calendarDays() {
        const now = new Date();
        const year = now.getFullYear();
        const month = now.getMonth();
        const first = new Date(year, month, 1);
        const start = first.getDay();
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const daysInPreviousMonth = new Date(year, month, 0).getDate();
        const result = [];

        for (let i = 0; i < 42; i++) {
            const day = i - start + 1;
            let value = day;
            let current = true;

            if (day < 1) {
                value = daysInPreviousMonth + day;
                current = false;
            } else if (day > daysInMonth) {
                value = day - daysInMonth;
                current = false;
            }

            result.push({
                day: value,
                current: current,
                today: current && value === now.getDate()
            });
        }

        return result;
    }

    ListModel {
        id: notificationHistory
    }

    ListModel {
        id: notificationPopups
    }

    NotificationServer {
        id: notificationServer
        bodySupported: true
        imageSupported: true
        actionsSupported: true

        onNotification: function(notification) {
            notification.tracked = true;

            const entry = {
                appName: notification.appName || "System",
                summary: notification.summary || "Notification",
                body: notification.body || ""
            };

            notificationHistory.insert(0, entry);

            if (!root.doNotDisturb) {
                notificationPopups.insert(0, entry);
                popupTrimTimer.restart();
            }
        }
    }

    Timer {
        id: popupTrimTimer
        interval: 5500
        onTriggered: {
            if (notificationPopups.count > 0) {
                notificationPopups.remove(notificationPopups.count - 1);
            }
            if (notificationPopups.count > 0) {
                restart();
            }
        }
    }

    Timer {
        id: trayCloseTimer
        interval: 260
        onTriggered: root.maybeCloseTrayPopup()
    }

    Process {
        id: statusProcess
        command: ["@STATUS_SCRIPT@"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    root.cpuText = data.cpu + "%";
                    root.memText = data.mem + "%";
                    root.tempText = data.temp === "--" ? "--" : data.temp + "C";
                    root.batteryText = data.battery;
                    root.networkText = data.network;
                    root.vpnText = data.vpn;
                    root.bluetoothText = data.bluetooth;
                    root.powerProfileText = data.powerProfile;
                    root.mediaStatus = data.mediaStatus;
                    root.mediaTitle = data.mediaTitle;
                } catch (e) {
                    console.log("hypr-shell status parse failed:", e);
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: statusProcess.running = true
    }

    Timer {
        id: statusRefreshTimer
        interval: 450
        onTriggered: statusProcess.running = true
    }

    Process {
        id: timezoneProcess
        command: ["@TIMEZONE_SCRIPT@"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    root.clockText = data.local;
                    root.localTime = data.local;
                    root.birminghamTime = data.birmingham;
                    root.lagosTime = data.lagos;
                    root.sanFranciscoTime = data.sanfrancisco;
                } catch (e) {
                    console.log("hypr-shell timezone parse failed:", e);
                }
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: timezoneProcess.running = true
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                required property var modelData

                screen: modelData
                color: "transparent"
                implicitHeight: 44

                anchors {
                    top: true
                    left: true
                    right: true
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#11111b"
                    border.color: "#313244"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        RowLayout {
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                            spacing: 8

                            Rectangle {
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: launcherText.implicitWidth + 22
                                radius: 8
                                color: "#313244"

                                Text {
                                    id: launcherText
                                    anchors.centerIn: parent
                                    text: "Launch"
                                    color: "#cdd6f4"
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.run("@VICINAE_COMMAND@")
                                }
                            }

                            Text {
                                text: "1 2 3 4 5"
                                color: "#6c7086"
                                font.pixelSize: 12
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: centerText.implicitWidth + 24
                            radius: 10
                            color: "#181825"
                            border.color: root.activePopup === "calendar" ? "#cba6f7" : "#313244"
                            border.width: 1

                            Text {
                                id: centerText
                                anchors.centerIn: parent
                                text: root.clockText
                                color: "#f5e0dc"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.togglePopup("calendar")
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            spacing: 6

                            Text {
                                text: root.mediaStatus === "Playing" ? root.mediaTitle : "Media idle"
                                color: root.mediaStatus === "Playing" ? "#a6e3a1" : "#6c7086"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.maximumWidth: 220

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.togglePopup("media")
                                }
                            }

                            Text {
                                text: "CPU " + root.cpuText
                                color: "#89b4fa"
                                font.pixelSize: 12
                            }

                            Text {
                                text: "MEM " + root.memText
                                color: "#94e2d5"
                                font.pixelSize: 12
                            }

                            Text {
                                text: "TMP " + root.tempText
                                color: "#fab387"
                                font.pixelSize: 12
                            }

                            Rectangle {
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: powerProfileText.implicitWidth + 18
                                radius: 8
                                color: "#181825"
                                border.color: "#313244"
                                border.width: 1

                                Text {
                                    id: powerProfileText
                                    anchors.centerIn: parent
                                    text: "PWR " + root.powerProfileText
                                    color: "#f9e2af"
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        root.run("@POWER_PROFILE_COMMAND@ cycle");
                                        root.refreshStatusSoon();
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: statusText.implicitWidth + 18
                                radius: 8
                                color: "#181825"

                                Text {
                                    id: statusText
                                    anchors.centerIn: parent
                                    text: root.networkText + " / VPN " + root.vpnText
                                    color: "#cdd6f4"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    width: Math.min(implicitWidth, 220)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.run("@NETWORK_COMMAND@")
                                }
                            }

                            Rectangle {
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: bluetoothText.implicitWidth + 18
                                radius: 8
                                color: "#181825"

                                Text {
                                    id: bluetoothText
                                    anchors.centerIn: parent
                                    text: "BT " + root.bluetoothText
                                    color: "#cdd6f4"
                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.run("@BLUETOOTH_COMMAND@")
                                }
                            }

                            Text {
                                text: root.batteryText
                                color: "#f9e2af"
                                font.pixelSize: 12
                            }

                            Rectangle {
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: 44
                                radius: 8
                                color: root.doNotDisturb ? "#f38ba8" : "#181825"

                                Text {
                                    anchors.centerIn: parent
                                    text: "DND"
                                    color: root.doNotDisturb ? "#11111b" : "#cdd6f4"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.doNotDisturb = !root.doNotDisturb
                                }
                            }

                            Rectangle {
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: notifText.implicitWidth + 18
                                radius: 8
                                color: root.activePopup === "notifications" ? "#313244" : "#181825"

                                Text {
                                    id: notifText
                                    anchors.centerIn: parent
                                    text: "Notifications " + notificationHistory.count
                                    color: "#cdd6f4"
                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.togglePopup("notifications")
                                }
                            }

                            Rectangle {
                                visible: SystemTray.items.count > 0
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: trayText.implicitWidth + 18
                                radius: 8
                                color: root.activePopup === "tray" ? "#313244" : "#181825"
                                border.color: root.activePopup === "tray" ? "#cba6f7" : "#313244"
                                border.width: 1

                                Text {
                                    id: trayText
                                    anchors.centerIn: parent
                                    text: "Tray " + SystemTray.items.count
                                    color: "#cdd6f4"
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: {
                                        root.trayButtonHovered = true;
                                        root.openTrayPopup(false);
                                    }
                                    onExited: {
                                        root.trayButtonHovered = false;
                                        root.scheduleTrayClose();
                                    }
                                    onClicked: {
                                        if (root.activePopup === "tray" && root.trayPinned) {
                                            root.trayPinned = false;
                                            root.activePopup = "";
                                        } else {
                                            root.openTrayPopup(true);
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: powerText.implicitWidth + 18
                                radius: 8
                                color: "#181825"
                                border.color: "#f38ba8"
                                border.width: 1

                                Text {
                                    id: powerText
                                    anchors.centerIn: parent
                                    text: "Power"
                                    color: "#f38ba8"
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.run("@POWER_COMMAND@")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        id: popover
        color: "transparent"
        visible: root.activePopup !== ""
        implicitHeight: 390
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            left: true
            right: true
        }

        Rectangle {
            id: popoverCard
            y: 52
            width: root.activePopup === "calendar" ? 390 : root.activePopup === "tray" ? 320 : 430
            height: root.activePopup === "calendar" ? 322 : root.activePopup === "tray" ? 230 : 280
            x: root.activePopup === "calendar" ? Math.round((parent.width - width) / 2) : parent.width - width - 12
            radius: 12
            color: "#11111b"
            border.color: "#313244"
            border.width: 1

            HoverHandler {
                onHoveredChanged: {
                    if (hovered) {
                    root.trayPopoverHovered = root.activePopup === "tray";
                    root.trayCloseTimer.stop();
                    } else {
                    root.trayPopoverHovered = false;
                    root.scheduleTrayClose();
                    }
                }
            }

            Loader {
                anchors.fill: parent
                anchors.margins: 16
                sourceComponent: root.activePopup === "calendar"
                    ? calendarComponent
                    : root.activePopup === "notifications"
                        ? notificationsComponent
                        : root.activePopup === "media"
                            ? mediaComponent
                            : root.activePopup === "tray"
                                ? trayComponent
                                : null
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: {
                root.trayPinned = false;
                root.activePopup = "";
            }
        }
    }

    Component {
        id: trayComponent

        ColumnLayout {
            spacing: 12

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "System Tray"
                    color: "#f5e0dc"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: SystemTray.items.count + " active"
                    color: "#6c7086"
                    font.pixelSize: 12
                }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Column {
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: SystemTray.items

                        delegate: Rectangle {
                            required property var modelData

                            width: parent.width
                            height: 42
                            radius: 10
                            color: trayItemMouse.containsMouse ? "#313244" : "#181825"
                            border.color: modelData.status === Status.NeedsAttention ? "#f38ba8" : "#313244"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 9
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    radius: 7
                                    color: "#11111b"

                                    Image {
                                        id: trayItemIcon
                                        anchors.centerIn: parent
                                        width: 18
                                        height: 18
                                        source: modelData.icon
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        visible: status === Image.Ready
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: trayItemIcon.status !== Image.Ready
                                        text: (modelData.title || modelData.id || "?").slice(0, 1).toUpperCase()
                                        color: "#cba6f7"
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.tooltipTitle || modelData.title || modelData.id || "Tray item"
                                        color: "#cdd6f4"
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        textFormat: Text.PlainText
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.tooltipDescription || (modelData.hasMenu ? "Menu available" : "Click to activate")
                                        color: "#a6adc8"
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        textFormat: Text.PlainText
                                    }
                                }
                            }

                            MouseArea {
                                id: trayItemMouse
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                hoverEnabled: true
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.RightButton || modelData.onlyMenu) {
                                        modelData.display(popover, popoverCard.x + popoverCard.width - 16, popoverCard.y + y + 16);
                                    } else {
                                        modelData.activate();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: calendarComponent

        ColumnLayout {
            spacing: 12

            Text {
                text: root.localTime
                color: "#f5e0dc"
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }

            RowLayout {
                spacing: 12

                Text { text: "Birmingham " + root.birminghamTime; color: "#cdd6f4"; font.pixelSize: 12 }
                Text { text: "Lagos " + root.lagosTime; color: "#cdd6f4"; font.pixelSize: 12 }
                Text { text: "San Francisco " + root.sanFranciscoTime; color: "#cdd6f4"; font.pixelSize: 12 }
            }

            Grid {
                columns: 7
                rowSpacing: 6
                columnSpacing: 6

                Repeater {
                    model: ["S", "M", "T", "W", "T", "F", "S"]
                    delegate: Text {
                        required property string modelData
                        width: 44
                        height: 20
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: "#6c7086"
                        font.pixelSize: 11
                    }
                }

                Repeater {
                    model: root.calendarDays()
                    delegate: Rectangle {
                        required property var modelData
                        width: 44
                        height: 30
                        radius: 8
                        color: modelData.today ? "#cba6f7" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.day
                            color: modelData.today ? "#11111b" : (modelData.current ? "#cdd6f4" : "#45475a")
                            font.pixelSize: 12
                            font.weight: modelData.today ? Font.DemiBold : Font.Normal
                        }
                    }
                }
            }
        }
    }

    Component {
        id: notificationsComponent

        ColumnLayout {
            spacing: 12

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Notifications"
                    color: "#f5e0dc"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "Clear"
                    onClicked: notificationHistory.clear()
                }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Column {
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: notificationHistory

                        delegate: Rectangle {
                            required property string appName
                            required property string summary
                            required property string body

                            width: parent.width
                            height: bodyText.text === "" ? 58 : 86
                            radius: 10
                            color: "#181825"
                            border.color: "#313244"
                            border.width: 1

                            Column {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4

                                Text {
                                    text: appName + " - " + summary
                                    color: "#cdd6f4"
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    width: parent.width
                                    textFormat: Text.PlainText
                                }

                                Text {
                                    id: bodyText
                                    text: body
                                    color: "#a6adc8"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    textFormat: Text.PlainText
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: mediaComponent

        ColumnLayout {
            spacing: 14

            Text {
                text: root.mediaTitle
                color: "#f5e0dc"
                font.pixelSize: 16
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.mediaStatus
                color: "#a6adc8"
                font.pixelSize: 12
            }

            RowLayout {
                spacing: 10

                Button { text: "Prev"; onClicked: root.run("playerctl previous") }
                Button { text: "Play"; onClicked: root.run("playerctl play-pause") }
                Button { text: "Next"; onClicked: root.run("playerctl next") }
            }
        }
    }

    PanelWindow {
        color: "transparent"
        visible: notificationPopups.count > 0 && !root.doNotDisturb
        implicitWidth: 360
        implicitHeight: 320
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            right: true
        }

        Column {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 54
            anchors.rightMargin: 12
            spacing: 8

            Repeater {
                model: notificationPopups

                delegate: Rectangle {
                    required property string appName
                    required property string summary
                    required property string body

                    width: 340
                    height: body === "" ? 68 : 94
                    radius: 12
                    color: "#11111b"
                    border.color: "#cba6f7"
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 5

                        Text {
                            text: appName + " - " + summary
                            color: "#f5e0dc"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            width: parent.width
                            textFormat: Text.PlainText
                        }

                        Text {
                            text: body
                            color: "#cdd6f4"
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            width: parent.width
                            textFormat: Text.PlainText
                        }
                    }
                }
            }
        }
    }
}
