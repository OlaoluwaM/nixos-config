pragma ComponentBehavior: Bound

//  Root shell configuration.
//
//  This file holds shared state, data pipes (shell script → QML), timers,
//  and the three PanelWindows that make up the desktop shell. Visual content
//  lives in Bar.qml, Popovers.qml, and ToastNotifications.qml. Colors and
//  sizing live in Theme.qml.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Wayland

Scope {
    id: root

    // ── Popup state ────────────────────────────────────────────────────
    property string activePopup: ""
    property bool doNotDisturb: false

    property bool trayButtonHovered: false
    property bool trayPopoverHovered: false
    property bool trayPinned: false
    property bool airplaneMode: false
    property bool toastsHovered: false
    property real trayMenuContentHeight: 0

    // ── OSD overlay state ──────────────────────────────────────────────
    property string osdIcon: "volume"
    property real osdValue: 0
    signal osdTriggered()

    property string popupCommandToken: ""
    property string popupCommandFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/hypr-shell/popup-command"

    // ── System status (populated by hypr-shell-status.sh) ──────────────
    property string clockText: "Loading"
    property string cpuText: "..."
    property string memText: "..."
    property string tempText: "..."
    property string volumeText: "N/A"
    property bool muted: false
    property string brightnessText: "N/A"
    property string powerProfileText: "Unavailable"
    property string batteryText: "AC"
    property string batteryHours: "--"
    property string batteryMinutes: "--"
    property string networkText: "Offline"
    property string vpnText: "Off"
    property string bluetoothText: "Off"
    property string bluetoothDevice: ""
    property string mediaStatus: "Stopped"
    property string mediaTitle: "No media"
    property string mediaArtist: ""
    property string mediaTrackTitle: "No media"
    property string mediaAlbumArt: ""
    property string mediaPosition: "0:00"
    property string mediaLength: "0:00"
    property string localTime: "Loading"
    property string birminghamTime: "..."
    property string lagosTime: "..."
    property string sanFranciscoTime: "..."

    property var notificationStore: ({})
    property int nextNotifId: 0
    readonly property int maxNotificationHistory: 20
    readonly property int trayItemCount: SystemTray.items.values.length

    readonly property bool mediaActive: mediaStatus === "Playing" || mediaStatus === "Paused"
    readonly property string mediaDisplayTitle:
        mediaArtist !== "" && mediaTrackTitle !== ""
            ? mediaArtist + " — " + mediaTrackTitle
            : mediaTrackTitle

    // ── Model aliases (so child components can bind) ───────────────────
    property alias notificationHistoryModel: notificationHistory
    property alias notificationPopupsModel: notificationPopups

    ListModel { id: notificationHistory }
    ListModel { id: notificationPopups  }

    // ── Popup helpers ──────────────────────────────────────────────────
    function togglePopup(name) {
        if (name !== "tray") trayPinned = false;
        activePopup = activePopup === name ? "" : name;
    }

    function openTrayPopup(pinned) {
        if (root.trayItemCount === 0) return;
        trayPinned = pinned;
        activePopup = "tray";
        trayCloseTimer.stop();
    }

    function scheduleTrayClose() {
        if (activePopup === "tray" && !trayPinned) trayCloseTimer.restart();
    }

    function maybeCloseTrayPopup() {
        if (activePopup === "tray" && !trayPinned && !trayButtonHovered && !trayPopoverHovered)
            activePopup = "";
    }

    // ── Confirm dialog helpers ────────────────────────────────────────
    function requestConfirmation(title, description, icon, danger, timeout, action) {
        activePopup = "";
        confirmDialog.request(title, description, icon, danger, timeout, action);
    }

    function dismissConfirmDialog() {
        confirmDialog.dismiss();
    }

    // ── Command helpers (keep here — Nix substitutes the paths) ────────
    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function run(command) {
        // Run a command, showing a notification if it fails.
        let script = command
            + "\nstatus=$?"
            + "\nif [ \"$status\" -ne 0 ]; then"
            + "\n  @NOTIFY_SEND_COMMAND@ --app-name=Quickshell --urgency=normal "
            + root.shellQuote(qsTr("Quickshell command failed"))
            + " \"Exit status: $status; Command: \""
            + root.shellQuote(command)
            + "\nfi"
            + "\nexit \"$status\"";

        Quickshell.execDetached(["sh", "-c", script]);
    }

    function refreshStatusSoon() {
        statusRefreshTimer.restart();
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

    function showOsd(icon, value) {
        root.osdIcon = icon;
        root.osdValue = value;
        root.osdTriggered();
    }

    function adjustVolume(delta) {
        let flag = delta > 0 ? "-i" : "-d";
        root.run("@PAMIXER_COMMAND@ " + flag + " " + Math.abs(delta));
        osdRefreshTimer.osdType = "volume";
        osdRefreshTimer.restart();
    }

    function adjustBrightness(delta) {
        let op = delta > 0 ? (delta + "%+") : (Math.abs(delta) + "%-");
        root.run("@BRIGHTNESS_COMMAND@ set " + op);
        osdRefreshTimer.osdType = "brightness";
        osdRefreshTimer.restart();
    }

    function adjustKbBacklight(delta) {
        let device = "--device='*::kbd_backlight'";
        let op = delta > 0 ? (delta + "%+") : (Math.abs(delta) + "%-");
        root.run("@BRIGHTNESS_COMMAND@ " + device + " set " + op);
        osdRefreshTimer.osdType = "keyboard";
        osdRefreshTimer.restart();
    }

    function toggleMute() {
        root.run("@PAMIXER_COMMAND@ -t");
        osdRefreshTimer.osdType = "volume";
        osdRefreshTimer.restart();
    }

    function isUnavailable(value) {
        return value === "" || value === "--" || value === "N/A" || value === "Unavailable";
    }

    function runPlayerctl(action) {
        root.runAndRefresh("@PLAYERCTL_COMMAND@ " + action);
    }

    // Named command wrappers — child components call these instead of
    // using raw command strings, keeping substitution targets in this file.
    function runPowerOffCommand()      { root.run("@POWER_COMMAND@"); }
    function runRebootCommand()        { root.run("@REBOOT_COMMAND@"); }
    function runNetworkCommand()      { root.run("@NETWORK_COMMAND@"); }
    function runBluetoothCommand()    { root.run("@BLUETOOTH_COMMAND@"); }
    function runPowerProfileCycle()   { root.runAndRefresh("@POWER_PROFILE_COMMAND@ cycle"); }
    function runPowerProfileSet(profile) { root.runAndRefresh("@POWER_PROFILE_COMMAND@ set " + profile); }
    function runLockCommand()         { root.run("@LOCK_COMMAND@"); }
    function runSleepCommand()        { root.run("@SLEEP_COMMAND@"); }
    function runRefreshCommand()      { root.run("@REFRESH_COMMAND@"); }
    function runLogoutCommand()       { root.run("@LOGOUT_COMMAND@"); }
    function toggleAirplaneMode() {
        root.airplaneMode = !root.airplaneMode;
        root.runAndRefresh("@RFKILL_COMMAND@ " + (root.airplaneMode ? "block" : "unblock") + " all");
    }

    // ── Notification helpers ───────────────────────────────────────────
    function addNotificationEntry(entry) {
        notificationHistory.insert(0, entry);
        while (notificationHistory.count > root.maxNotificationHistory) {
            let old = notificationHistory.get(notificationHistory.count - 1);
            delete root.notificationStore[old.notifId];
            notificationHistory.remove(notificationHistory.count - 1);
        }
    }

    function removeFromModel(model, notifId) {
        for (let i = model.count - 1; i >= 0; i--) {
            if (model.get(i).notifId === notifId) {
                model.remove(i);
                break;
            }
        }
    }

    function invokeNotifAction(notifId, actionIndex) {
        try {
            let notif = notificationStore[notifId];
            if (!notif || actionIndex >= notif.actions.length) return;
            notif.actions[actionIndex].invoke();
            if (!notif.resident) removeFromModel(notificationPopups, notifId);
        } catch(e) {}
    }

    function dismissNotifPopup(notifId) {
        removeFromModel(notificationPopups, notifId);
    }

    function dismissNotifHistory(notifId) {
        try { let notif = notificationStore[notifId]; if (notif) notif.dismiss(); } catch(e) {}
        delete notificationStore[notifId];
        removeFromModel(notificationHistory, notifId);
    }

    function clearAllNotifications() {
        for (let i = 0; i < notificationHistory.count; i++) {
            let item = notificationHistory.get(i);
            try { let notif = notificationStore[item.notifId]; if (notif) notif.dismiss(); } catch(e) {}
            delete notificationStore[item.notifId];
        }
        notificationHistory.clear();
    }

    // ── Popup command channel (keybind → shell file → QML) ─────────────
    function handlePopupCommand(text) {
        let trimmed = text.trim();
        if (trimmed === "") return;
        let parts = trimmed.split(/\s+/);
        let token = parts[0] || "";
        let command = parts[1] || "";
        if (token === "" || token === root.popupCommandToken) return;
        root.popupCommandToken = token;
        switch (command) {
            case "quickSettings": root.togglePopup("quickSettings"); break;
            case "osd-volume": osdRefreshTimer.osdType = "volume"; osdRefreshTimer.restart(); break;
            case "osd-brightness": osdRefreshTimer.osdType = "brightness"; osdRefreshTimer.restart(); break;
            case "osd-keyboard": osdRefreshTimer.osdType = "keyboard"; osdRefreshTimer.restart(); break;
            case "osd-mute": osdRefreshTimer.osdType = "volume"; osdRefreshTimer.restart(); break;
        }
    }

    // ── Notification server ────────────────────────────────────────────
    NotificationServer {
        bodySupported: true
        imageSupported: true
        actionsSupported: true

        onNotification: function(notification) {
            notification.tracked = true;
            let id = root.nextNotifId++;
            root.notificationStore[id] = notification;

            let labels = [];
            for (let i = 0; i < notification.actions.length; i++)
                labels.push(notification.actions[i].text);

            let entry = {
                notifId: id,
                appName: notification.appName || "System",
                summary: notification.summary || "Notification",
                body: notification.body || "",
                timestamp: Date.now(),
                hasActions: notification.actions.length > 0,
                actionLabels: JSON.stringify(labels),
                urgency: notification.urgency || 0
            };
            root.addNotificationEntry(entry);
            if (!root.doNotDisturb) {
                notificationPopups.insert(0, entry);
                popupTrimTimer.restart();
            }
        }
    }

    // ── Timers ─────────────────────────────────────────────────────────
    Timer {
        id: popupTrimTimer
        interval: 5500
        onTriggered: {
            if (root.toastsHovered) {
                restart();
                return;
            }
            if (notificationPopups.count > 0)
                notificationPopups.remove(notificationPopups.count - 1);
            if (notificationPopups.count > 0)
                restart();
        }
    }

    Timer {
        id: trayCloseTimer
        interval: 260
        onTriggered: root.maybeCloseTrayPopup()
    }

    // ── Data pipes (shell scripts → QML properties) ────────────────────
    Process {
        id: statusProcess
        command: ["@STATUS_SCRIPT@"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text);
                    root.cpuText         = data.cpu + "%";
                    root.memText         = data.mem + "%";
                    root.tempText        = root.isUnavailable(data.temp) ? "N/A" : data.temp + "°C";
                    root.volumeText      = data.volume;
                    root.muted           = data.muted === "true";
                    root.brightnessText  = data.brightness;
                    root.batteryText     = data.battery;
                    root.batteryHours    = data.batteryHours || "--";
                    root.batteryMinutes  = data.batteryMinutes || "--";
                    root.networkText     = data.network;
                    root.vpnText         = data.vpn;
                    root.bluetoothText   = data.bluetooth;
                    root.bluetoothDevice = data.bluetoothDevice || "";
                    root.powerProfileText = data.powerProfile;
                    root.mediaStatus     = data.mediaStatus;
                    root.mediaTitle      = data.mediaTitle;
                    root.mediaArtist     = data.mediaArtist || "";
                    root.mediaTrackTitle = data.mediaTrackTitle || data.mediaTitle || "No media";
                    root.mediaAlbumArt   = data.mediaAlbumArt || "";
                    root.mediaPosition   = data.mediaPosition || "0:00";
                    root.mediaLength     = data.mediaLength || "0:00";
                } catch (e) {
                    console.log("hypr-shell status parse failed:", e);
                }
            }
        }
    }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: statusProcess.running = true }
    Timer { id: statusRefreshTimer; interval: 450; onTriggered: statusProcess.running = true }

    Timer {
        id: osdRefreshTimer
        property string osdType: ""
        interval: 30
        onTriggered: osdReadProcess.running = true
    }

    Process {
        id: osdReadProcess
        command: ["sh", "-c",
            "vol=$(@PAMIXER_COMMAND@ --get-volume 2>/dev/null || echo -1);" +
            "mute=$(@PAMIXER_COMMAND@ --get-mute 2>/dev/null || echo false);" +
            "bri=$(@BRIGHTNESS_COMMAND@ -m 2>/dev/null | awk -F, '{print $4}' | tr -d '%');" +
            "kbd=$(@BRIGHTNESS_COMMAND@ -m -d '*::kbd_backlight' 2>/dev/null | awk -F, '{print $4}' | tr -d '%');" +
            "printf '%s %s %s %s' \"$vol\" \"$mute\" \"${bri:--1}\" \"${kbd:--1}\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split(" ");
                let vol = parseInt(parts[0]) || 0;
                let muted = parts[1] === "true";
                let bri = parseInt(parts[2]) || 0;
                let kbd = parseInt(parts[3]) || 0;

                if (vol >= 0) {
                    root.volumeText = vol + "%";
                    root.muted = muted;
                }
                if (bri >= 0) root.brightnessText = bri + "%";

                let t = osdRefreshTimer.osdType;
                if (t === "volume") {
                    root.showOsd(muted ? "volumeMuted" : "volume", vol);
                } else if (t === "brightness") {
                    root.showOsd("brightness", bri);
                } else if (t === "keyboard") {
                    root.showOsd("keyboard", kbd);
                }
            }
        }
    }

    Process {
        id: timezoneProcess
        command: ["@TIMEZONE_SCRIPT@"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text);
                    root.clockText        = data.local;
                    root.localTime        = data.local;
                    root.birminghamTime   = data.birmingham;
                    root.lagosTime        = data.lagos;
                    root.sanFranciscoTime = data.sanfrancisco;
                } catch (e) {
                    console.log("hypr-shell timezone parse failed:", e);
                }
            }
        }
    }

    Timer { interval: 30000; running: true; repeat: true; onTriggered: timezoneProcess.running = true }

    // Seed the token from any leftover file so stale commands aren't replayed.
    Process {
        id: popupSeedProcess
        command: ["sh", "-c", "cat '" + root.popupCommandFile + "' 2>/dev/null || true"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let token = this.text.trim().split(/\s+/)[0] || "";
                if (token !== "") root.popupCommandToken = token;
                popupPollTimer.running = true;
            }
        }
    }

    Process {
        id: popupCommandProcess
        command: ["sh", "-c", "cat '" + root.popupCommandFile + "' 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: root.handlePopupCommand(this.text)
        }
    }

    Timer { id: popupPollTimer; interval: 250; repeat: true; onTriggered: popupCommandProcess.running = true }

    // ════════════════════════════════════════════════════════════════════
    //  Windows
    // ════════════════════════════════════════════════════════════════════

    // ── Top bar ────────────────────────────────────────────────────────
    PanelWindow {
        visible: true
        color: "transparent"
        aboveWindows: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-topbar"

        implicitWidth: 1200
        // The visible bar is 62px tall. The window is taller so bar tooltips
        // can draw below the capsules instead of being clipped by layer-shell.
        implicitHeight: 96
        exclusiveZone: 70

        margins { top: 6; left: 10; right: 10; bottom: 0 }
        anchors { top: true; left: true; right: true }

        Bar {
            shell: root
            height: 62
            anchors { top: parent.top; left: parent.left; right: parent.right }
        }
    }

    // ── Popovers ───────────────────────────────────────────────────────
    Popovers { shell: root }

    // ── Toast notifications ────────────────────────────────────────────
    ToastNotifications { shell: root }

    // ── OSD overlay (volume / brightness / keyboard backlight) ─────────
    OsdOverlay { shell: root }

    // ── Confirm dialog ────────────────────────────────────────────────
    ConfirmDialog {
        id: confirmDialog

        onAccepted: function(action) {
            switch (action) {
                case "logout": root.runLogoutCommand(); break;
                case "reboot": root.runRebootCommand(); break;
                case "suspend": root.runSleepCommand(); break;
                case "poweroff": root.runPowerOffCommand(); break;
            }
        }
    }
}
