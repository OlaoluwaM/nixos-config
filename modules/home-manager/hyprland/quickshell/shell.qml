pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
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
    property int calendarMonthOffset: 0
    property string popupCommandToken: ""
    property string popupCommandFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/hypr-shell/popup-command"
    property string clockText: "--"
    property string cpuText: "--"
    property string memText: "--"
    property string tempText: "--"
    property string volumeText: "--"
    property bool muted: false
    property string brightnessText: "--"
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
    readonly property int maxNotificationHistory: 20
    readonly property int trayItemCount: SystemTray.items.values.length

    function togglePopup(name) {
        if (name !== "tray") {
            trayPinned = false;
        }
        activePopup = activePopup === name ? "" : name;
    }

    function openTrayPopup(pinned) {
        if (root.trayItemCount === 0) {
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

    function icon(name) {
        const icons = {
            cpu: "",
            memory: "",
            temp: "",
            volume: muted ? "󰝟" : "󰕾",
            brightness: "󰃟",
            network: networkText === "offline" ? "󰤮" : "󰤨",
            vpn: vpnText === "off" ? "󰌾" : "󰌆",
            bluetooth: "󰂯",
            battery: batteryText === "AC" ? "󰚥" : "󰁹",
            notifications: root.doNotDisturb ? "󰂛" : "󰂚",
            tray: "󰇙",
            quick: "󰒓",
            power: "",
            media: root.mediaStatus === "Playing" ? "󰐊" : "󰝛",
            left: "󰅁",
            right: "󰅂"
        };
        return icons[name] || "";
    }

    function runAndRefresh(command) {
        root.run(command);
        root.refreshStatusSoon();
    }

    function setVolume(value) {
        root.runAndRefresh("@PAMIXER_COMMAND@ --set-volume " + Math.round(value));
    }

    function setBrightness(value) {
        root.runAndRefresh("@BRIGHTNESS_COMMAND@ set " + Math.round(value) + "%");
    }

    function runPlayerctl(action) {
        root.runAndRefresh("@PLAYERCTL_COMMAND@ " + action);
    }

    function addNotificationEntry(entry) {
        notificationHistory.insert(0, entry);
        while (notificationHistory.count > root.maxNotificationHistory) {
            notificationHistory.remove(notificationHistory.count - 1);
        }
    }

    function handlePopupCommand(text) {
        const trimmed = text.trim();
        if (trimmed === "") {
            return;
        }

        const parts = trimmed.split(/\s+/);
        const token = parts[0] || "";
        const command = parts[1] || "";

        if (token === "" || token === root.popupCommandToken) {
            return;
        }

        root.popupCommandToken = token;
        if (command === "quickSettings") {
            root.togglePopup("quickSettings");
        }
    }

    function calendarDate() {
        const now = new Date();
        return new Date(now.getFullYear(), now.getMonth() + root.calendarMonthOffset, 1);
    }

    function calendarTitle() {
        return root.calendarDate().toLocaleDateString(undefined, {
            month: "long",
            year: "numeric"
        });
    }

    function calendarDays() {
        const now = new Date();
        const target = root.calendarDate();
        const year = target.getFullYear();
        const month = target.getMonth();
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
                today: current && value === now.getDate() && month === now.getMonth() && year === now.getFullYear()
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

            root.addNotificationEntry(entry);

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
                    root.volumeText = data.volume;
                    root.muted = data.muted === "true";
                    root.brightnessText = data.brightness;
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

    Process {
        id: popupCommandProcess
        command: ["sh", "-c", "cat '" + root.popupCommandFile + "' 2>/dev/null || true"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.handlePopupCommand(this.text)
        }
    }

    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: popupCommandProcess.running = true
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                required property var modelData

                screen: modelData
                color: "transparent"
                height: 46
                exclusiveZone: 58

                margins {
                    top: 8
                    left: 12
                    right: 12
                    bottom: 0
                }

                anchors {
                    top: true
                    left: true
                    right: true
                }

                Rectangle {
                    id: topBar
                    anchors.fill: parent
                    radius: 14
                    color: "#11111bcc"
                    border.color: "#313244"
                    border.width: 1
                    clip: true

                    Row {
                        id: workspaceRow
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Repeater {
                            model: Hyprland.workspaces

                            delegate: Rectangle {
                                required property var modelData

                                property bool occupied: modelData.toplevels.values.length > 0
                                property bool shown: modelData.active || occupied
                                property string label: modelData.name || modelData.id

                                visible: shown
                                width: shown ? Math.max(28, wsLabel.implicitWidth + 14) : 0
                                height: 28
                                radius: 9
                                color: modelData.focused ? "#cba6f7" : (modelData.active ? "#585b70" : "#181825")
                                border.color: modelData.urgent ? "#f38ba8" : "#313244"
                                border.width: 1

                                Text {
                                    id: wsLabel
                                    anchors.centerIn: parent
                                    text: parent.label
                                    color: modelData.focused ? "#11111b" : "#cdd6f4"
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: modelData.activate()
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: clockPill
                        anchors.centerIn: parent
                        width: centerText.implicitWidth + 26
                        height: 30
                        radius: 10
                        color: root.activePopup === "calendar" ? "#313244" : "#181825"
                        border.color: root.activePopup === "calendar" ? "#cba6f7" : "#45475a"
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

                    Row {
                        id: rightStatus
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Rectangle {
                            width: mediaIcon.implicitWidth + 16
                            height: 28
                            radius: 9
                            color: root.activePopup === "media" ? "#313244" : "#181825"
                            visible: root.mediaStatus === "Playing"

                            Text {
                                id: mediaIcon
                                anchors.centerIn: parent
                                text: root.icon("media")
                                color: "#a6e3a1"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 15
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.togglePopup("media")
                            }
                        }

                        Text {
                            text: root.icon("cpu") + " " + root.cpuText
                            color: "#89b4fa"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 12
                        }

                        Text {
                            text: root.icon("memory") + " " + root.memText
                            color: "#94e2d5"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 12
                        }

                        Text {
                            text: root.icon("temp") + " " + root.tempText
                            color: "#fab387"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 12
                        }

                        Rectangle {
                            width: 34
                            height: 28
                            radius: 9
                            color: root.activePopup === "quickSettings" ? "#313244" : "#181825"
                            border.color: root.activePopup === "quickSettings" ? "#cba6f7" : "#313244"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: root.icon("quick")
                                color: "#cdd6f4"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 15
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.togglePopup("quickSettings")
                            }
                        }

                        Rectangle {
                            width: 34
                            height: 28
                            radius: 9
                            color: root.activePopup === "notifications" ? "#313244" : "#181825"

                            Text {
                                anchors.centerIn: parent
                                text: notificationHistory.count > 0 ? root.icon("notifications") + " " + notificationHistory.count : root.icon("notifications")
                                color: root.doNotDisturb ? "#f38ba8" : "#cdd6f4"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 13
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.togglePopup("notifications")
                            }
                        }

                        Rectangle {
                            visible: root.trayItemCount > 0
                            width: root.trayItemCount > 0 ? 34 : 0
                            height: 28
                            radius: 9
                            color: root.activePopup === "tray" ? "#313244" : "#181825"
                            border.color: root.activePopup === "tray" ? "#cba6f7" : "#313244"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: root.icon("tray")
                                color: "#cdd6f4"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 14
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
            y: 66
            width: root.activePopup === "calendar" ? 420 : root.activePopup === "tray" ? 320 : root.activePopup === "quickSettings" ? 430 : 430
            height: root.activePopup === "calendar" ? 380 : root.activePopup === "tray" ? 230 : root.activePopup === "quickSettings" ? 520 : 280
            x: root.activePopup === "calendar" ? Math.round((parent.width - width) / 2) : parent.width - width - 12
            radius: 16
            color: "#11111bf2"
            border.color: "#313244"
            border.width: 1

            HoverHandler {
                onHoveredChanged: {
                    if (hovered) {
                        root.trayPopoverHovered = root.activePopup === "tray";
                        trayCloseTimer.stop();
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
                                : root.activePopup === "quickSettings"
                                    ? quickSettingsComponent
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
        id: quickSettingsComponent

        ColumnLayout {
            spacing: 14

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Quick Settings"
                        color: "#f5e0dc"
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: root.networkText + " / VPN " + root.vpnText
                        color: "#a6adc8"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    radius: 12
                    color: "#181825"
                    border.color: "#f38ba8"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.icon("power")
                        color: "#f38ba8"
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 17
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.run("@POWER_COMMAND@")
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 86
                radius: 14
                color: "#181825"
                border.color: "#313244"
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: root.icon("volume")
                            color: root.muted ? "#6c7086" : "#89b4fa"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 18
                        }

                        Slider {
                            Layout.fillWidth: true
                            from: 0
                            to: 100
                            value: Number(root.volumeText.replace("%", "")) || 0
                            onMoved: root.setVolume(value)
                        }

                        Text {
                            Layout.preferredWidth: 42
                            horizontalAlignment: Text.AlignRight
                            text: root.volumeText
                            color: "#cdd6f4"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: root.icon("brightness")
                            color: "#f9e2af"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 18
                        }

                        Slider {
                            Layout.fillWidth: true
                            from: 1
                            to: 100
                            value: Number(root.brightnessText.replace("%", "")) || 50
                            onMoved: root.setBrightness(value)
                        }

                        Text {
                            Layout.preferredWidth: 42
                            horizontalAlignment: Text.AlignRight
                            text: root.brightnessText
                            color: "#cdd6f4"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 10
                columnSpacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 68
                    radius: 14
                    color: root.networkText === "offline" ? "#181825" : "#89b4fa"
                    border.color: "#313244"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        Text {
                            text: root.icon("network")
                            color: root.networkText === "offline" ? "#6c7086" : "#11111b"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 18
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text { text: "Network"; color: root.networkText === "offline" ? "#cdd6f4" : "#11111b"; font.pixelSize: 12; font.weight: Font.DemiBold }
                            Text { text: root.networkText; color: root.networkText === "offline" ? "#a6adc8" : "#313244"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.run("@NETWORK_COMMAND@")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 68
                    radius: 14
                    color: root.vpnText === "off" ? "#181825" : "#a6e3a1"
                    border.color: "#313244"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        Text {
                            text: root.icon("vpn")
                            color: root.vpnText === "off" ? "#6c7086" : "#11111b"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 18
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text { text: "VPN"; color: root.vpnText === "off" ? "#cdd6f4" : "#11111b"; font.pixelSize: 12; font.weight: Font.DemiBold }
                            Text { text: root.vpnText; color: root.vpnText === "off" ? "#a6adc8" : "#313244"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.run("@NETWORK_COMMAND@")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 68
                    radius: 14
                    color: root.bluetoothText === "on" ? "#74c7ec" : "#181825"
                    border.color: "#313244"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        Text {
                            text: root.icon("bluetooth")
                            color: root.bluetoothText === "on" ? "#11111b" : "#6c7086"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 18
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text { text: "Bluetooth"; color: root.bluetoothText === "on" ? "#11111b" : "#cdd6f4"; font.pixelSize: 12; font.weight: Font.DemiBold }
                            Text { text: root.bluetoothText; color: root.bluetoothText === "on" ? "#313244" : "#a6adc8"; font.pixelSize: 11 }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.run("@BLUETOOTH_COMMAND@")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 68
                    radius: 14
                    color: root.doNotDisturb ? "#f38ba8" : "#181825"
                    border.color: "#313244"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        Text {
                            text: root.icon("notifications")
                            color: root.doNotDisturb ? "#11111b" : "#6c7086"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 18
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text { text: "Do Not Disturb"; color: root.doNotDisturb ? "#11111b" : "#cdd6f4"; font.pixelSize: 12; font.weight: Font.DemiBold }
                            Text { text: root.doNotDisturb ? "On" : "Off"; color: root.doNotDisturb ? "#313244" : "#a6adc8"; font.pixelSize: 11 }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.doNotDisturb = !root.doNotDisturb
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    radius: 14
                    color: "#181825"
                    border.color: "#313244"
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 3

                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.powerProfileText; color: "#f9e2af"; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Power Mode"; color: "#a6adc8"; font.pixelSize: 11 }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.runAndRefresh("@POWER_PROFILE_COMMAND@ cycle")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    radius: 14
                    color: "#181825"
                    border.color: "#313244"
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 3

                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.batteryText; color: "#a6e3a1"; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Battery"; color: "#a6adc8"; font.pixelSize: 11 }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Repeater {
                    model: [
                        { label: "CPU", value: root.cpuText, color: "#89b4fa" },
                        { label: "MEM", value: root.memText, color: "#94e2d5" },
                        { label: "TEMP", value: root.tempText, color: "#fab387" }
                    ]

                    delegate: Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        radius: 14
                        color: "#181825"
                        border.color: "#313244"
                        border.width: 1

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.value; color: modelData.color; font.pixelSize: 13; font.weight: Font.DemiBold }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: "#a6adc8"; font.pixelSize: 10 }
                        }
                    }
                }
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
                    text: root.trayItemCount + " active"
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
                                        sourceSize.width: 18
                                        sourceSize.height: 18
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
            spacing: 14

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: root.localTime
                        color: "#f5e0dc"
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: root.calendarTitle()
                        color: "#a6adc8"
                        font.pixelSize: 12
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 30
                    radius: 9
                    color: "#181825"
                    border.color: "#313244"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.icon("left")
                        color: "#cdd6f4"
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 15
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.calendarMonthOffset -= 1
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 30
                    radius: 9
                    color: "#181825"
                    border.color: "#313244"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.icon("right")
                        color: "#cdd6f4"
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 15
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.calendarMonthOffset += 1
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: 8
                columnSpacing: 8

                Repeater {
                    model: [
                        { city: "Birmingham", time: root.birminghamTime },
                        { city: "Lagos", time: root.lagosTime },
                        { city: "San Francisco", time: root.sanFranciscoTime }
                    ]

                    delegate: Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 12
                        color: "#181825"
                        border.color: "#313244"
                        border.width: 1

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.time
                                color: "#cdd6f4"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.city
                                color: "#a6adc8"
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }

            Grid {
                Layout.alignment: Qt.AlignHCenter
                columns: 7
                rowSpacing: 7
                columnSpacing: 7

                Repeater {
                    model: ["S", "M", "T", "W", "T", "F", "S"]
                    delegate: Text {
                        required property string modelData
                        width: 46
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
                        width: 46
                        height: 32
                        radius: 10
                        color: modelData.today ? "#cba6f7" : (modelData.current ? "#181825" : "transparent")
                        border.color: modelData.current ? "#313244" : "transparent"
                        border.width: 1

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

                Button { text: "Prev"; onClicked: root.runPlayerctl("previous") }
                Button { text: "Play"; onClicked: root.runPlayerctl("play-pause") }
                Button { text: "Next"; onClicked: root.runPlayerctl("next") }
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
