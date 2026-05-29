pragma ComponentBehavior: Bound

//  Root shell configuration.
//
//  This file wires shared services, command-backed data pipes, timers, and the
//  three PanelWindows that make up the desktop shell. Visual content lives in
//  Bar.qml, Popovers.qml, and ToastNotifications.qml. Colors, sizing, and
//  generated command paths live in Theme.qml and GeneratedCommands.qml.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Wayland

Scope {
    id: root

    // ── Confirm dialog helpers ────────────────────────────────────────
    function requestConfirmation(title, description, icon, danger, timeout, action) {
        popupController.close();
        confirmDialog.request(title, description, icon, danger, timeout, action);
    }

    function dismissConfirmDialog() {
        confirmDialog.dismiss();
    }

    // ── Data pipes (shell scripts → QML properties) ────────────────────
    Process {
        id: statusProcess
        command: [GeneratedCommands.statusScript]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text);
                    // Write straight to the owning status domain via the facade's
                    // ingestion alias; the controller stays a pure state facade.
                    statusController.systemStatus.updateStatus(data);
                } catch (e) {
                    console.log("hypr-shell status parse failed:", e);
                }
                statusPollTimer.restart();
            }
        }
    }

    // The periodic poll is self-scheduling: each run arms the next one 2s after
    // it finishes (above), so a slow poll can never overlap or stack with the
    // next. statusProcess.running starts the first poll at launch.
    Timer { id: statusPollTimer; interval: 2000; onTriggered: statusProcess.running = true }
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
            "bri=$(" + GeneratedCommands.brightnessCommand + " -m 2>/dev/null | awk -F, '{print $4}' | tr -d '%');" +
            "kbd=$(" + GeneratedCommands.brightnessCommand + " -m -d '*::kbd_backlight' 2>/dev/null | awk -F, '{print $4}' | tr -d '%');" +
            "printf '%s %s' \"${bri:--1}\" \"${kbd:--1}\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split(" ");
                let bri = parseInt(parts[0]) || 0;
                let kbd = parseInt(parts[1]) || 0;

                statusController.systemStatus.updateOsdReadings(bri);

                let t = osdRefreshTimer.osdType;
                // bri/kbd come through as -1 when the device has no backlight
                // (the shell prints the -1 sentinel). Suppress the OSD in that
                // case instead of flashing a phantom 0% bar.
                if (t === "volume") {
                    osdController.show(Icons.volumeName(statusController.muted, statusController.volumePercent), statusController.volumePercent);
                } else if (t === "brightness") {
                    if (bri >= 0) osdController.show("brightness", bri);
                } else if (t === "keyboard") {
                    if (kbd >= 0) osdController.show("keyboard", kbd);
                }
            }
        }
    }

    Process {
        id: timezoneProcess
        command: [GeneratedCommands.timezoneScript]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text);
                    statusController.systemStatus.updateTimezones(data);
                } catch (e) {
                    console.log("hypr-shell timezone parse failed:", e);
                }
            }
        }
    }

    Timer { interval: 30000; running: true; repeat: true; onTriggered: timezoneProcess.running = true }

    // ════════════════════════════════════════════════════════════════════
    //  Windows
    // ════════════════════════════════════════════════════════════════════

    // ── Notification service ──────────────────────────────────────────
    NotificationService { id: notificationService }

    // ── Status controller ─────────────────────────────────────────────
    StatusController { id: statusController }

    // ── Command runner and domain actions ─────────────────────────────
    CommandRunner {
        id: commandRunner
        onOsdRefreshRequested: function(osdType) {
            osdRefreshTimer.osdType = osdType;
            osdRefreshTimer.restart();
        }

        onStatusRefreshRequested: statusRefreshTimer.restart()
    }

    AudioActions { id: audioActions; runner: commandRunner; status: statusController }
    BrightnessActions { id: brightnessActions; runner: commandRunner }
    CaffeineActions { id: caffeineActions; runner: commandRunner; status: statusController }
    MediaActions { id: mediaActions; status: statusController }
    ConnectivityActions { id: connectivityActions; runner: commandRunner; status: statusController }

    PowerActions {
        id: powerActions
        runner: commandRunner

        onConfirmationRequested: function(title, description, icon, danger, timeout, action) {
            root.requestConfirmation(title, description, icon, danger, timeout, action);
        }
    }

    // ── Popup controller ──────────────────────────────────────────────
    PopupController {
        id: popupController
        trayItemCount: SystemTray.items.values.length
    }

    // ── OSD controller ────────────────────────────────────────────────
    OsdController { id: osdController }

    // ── Popup command bridge (Hyprland keybind file → QML signals) ────
    PopupCommandBridge {
        onQuickSettingsRequested: popupController.toggle("quickSettings")
        onAudioUpRequested: audioActions.adjustVolume(5)
        onAudioDownRequested: audioActions.adjustVolume(-5)
        onAudioMuteRequested: audioActions.toggleMute()
        onOsdRefreshRequested: function(osdType) {
            commandRunner.refreshOsd(osdType);
        }
    }

    // ── Top bar ────────────────────────────────────────────────────────
    PanelWindow {
        visible: true
        color: "transparent"
        aboveWindows: true
        implicitWidth: 1200
        // The visible bar is 62px tall. The window is taller so bar tooltips
        // can draw below the capsules instead of being clipped by layer-shell.
        implicitHeight: 96
        exclusiveZone: 70

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-topbar"

        margins { top: 6; left: 10; right: 10; bottom: 0 }
        anchors { top: true; left: true; right: true }

        Bar {
            caffeineActions: caffeineActions
            connectivityActions: connectivityActions
            mediaActions: mediaActions
            status: statusController
            notifications: notificationService
            popups: popupController
            height: 62
            anchors { top: parent.top; left: parent.left; right: parent.right }
        }
    }

    // ── Popovers ───────────────────────────────────────────────────────
    Popovers {
        audioActions: audioActions
        brightnessActions: brightnessActions
        connectivityActions: connectivityActions
        mediaActions: mediaActions
        powerActions: powerActions
        status: statusController
        notifications: notificationService
        popups: popupController
    }

    // ── Toast notifications ────────────────────────────────────────────
    ToastNotifications { notifications: notificationService }

    // ── OSD overlay (volume / brightness / keyboard backlight) ─────────
    OsdOverlay { osd: osdController }

    // ── Confirm dialog ────────────────────────────────────────────────
    ConfirmDialog {
        id: confirmDialog

        onAccepted: function(action) {
            switch (action) {
                case "logout": powerActions.runLogoutCommand(); break;
                case "reboot": powerActions.runRebootCommand(); break;
                case "suspend": powerActions.runSleepCommand(); break;
                case "poweroff": powerActions.runPowerOffCommand(); break;
            }
        }
    }
}
