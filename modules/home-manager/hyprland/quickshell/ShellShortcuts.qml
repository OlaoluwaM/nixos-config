pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Hyprland

Scope {
    id: root

    required property PopupController popups
    required property AudioActions audioActions
    required property BrightnessActions brightnessActions

    property string heldAction: ""

    function startHoldRepeat(action) {
        root.runAction(action);
        root.heldAction = action;
        holdRepeatDelayTimer.restart();
    }

    function stopHoldRepeat() {
        root.heldAction = "";
        holdRepeatDelayTimer.stop();
        holdRepeatTimer.stop();
    }

    function repeatHeldAction() {
        if (root.heldAction.length === 0 || !root.anyRepeatShortcutPressed()) {
            root.stopHoldRepeat();
            return;
        }

        root.runAction(root.heldAction);
    }

    function runAction(action) {
        switch (action) {
            case "audioUp": root.audioActions.adjustVolume(5); break;
            case "audioDown": root.audioActions.adjustVolume(-5); break;
            case "brightnessUp": root.brightnessActions.adjustBrightness(5); break;
            case "brightnessDown": root.brightnessActions.adjustBrightness(-5); break;
            case "keyboardBrightnessUp": root.brightnessActions.adjustKbBacklight(5); break;
            case "keyboardBrightnessDown": root.brightnessActions.adjustKbBacklight(-5); break;
        }
    }

    function anyRepeatShortcutPressed() {
        return audioUpShortcut.pressed
            || audioDownShortcut.pressed
            || brightnessUpShortcut.pressed
            || brightnessDownShortcut.pressed
            || keyboardBrightnessUpShortcut.pressed
            || keyboardBrightnessDownShortcut.pressed;
    }

    // Hyprland still declares the physical key chords in default.nix. The
    // `global` dispatcher sends those chords here as `quickshell:<name>`, and
    // this file defines what each named shell shortcut actually does.
    GlobalShortcut {
        appid: "quickshell"
        name: "quickSettings"
        description: qsTr("Toggle quick settings")
        onPressed: root.popups.toggle("quickSettings")
    }

    GlobalShortcut {
        id: audioUpShortcut
        appid: "quickshell"
        name: "audioUp"
        description: qsTr("Raise volume")
        onPressed: root.startHoldRepeat("audioUp")
        onReleased: root.stopHoldRepeat()
    }

    GlobalShortcut {
        id: audioDownShortcut
        appid: "quickshell"
        name: "audioDown"
        description: qsTr("Lower volume")
        onPressed: root.startHoldRepeat("audioDown")
        onReleased: root.stopHoldRepeat()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "audioMute"
        description: qsTr("Toggle mute")
        onPressed: root.audioActions.toggleMute()
    }

    GlobalShortcut {
        id: brightnessUpShortcut
        appid: "quickshell"
        name: "brightnessUp"
        description: qsTr("Raise display brightness")
        onPressed: root.startHoldRepeat("brightnessUp")
        onReleased: root.stopHoldRepeat()
    }

    GlobalShortcut {
        id: brightnessDownShortcut
        appid: "quickshell"
        name: "brightnessDown"
        description: qsTr("Lower display brightness")
        onPressed: root.startHoldRepeat("brightnessDown")
        onReleased: root.stopHoldRepeat()
    }

    GlobalShortcut {
        id: keyboardBrightnessUpShortcut
        appid: "quickshell"
        name: "keyboardBrightnessUp"
        description: qsTr("Raise keyboard brightness")
        onPressed: root.startHoldRepeat("keyboardBrightnessUp")
        onReleased: root.stopHoldRepeat()
    }

    GlobalShortcut {
        id: keyboardBrightnessDownShortcut
        appid: "quickshell"
        name: "keyboardBrightnessDown"
        description: qsTr("Lower keyboard brightness")
        onPressed: root.startHoldRepeat("keyboardBrightnessDown")
        onReleased: root.stopHoldRepeat()
    }

    Timer {
        id: holdRepeatDelayTimer
        interval: 260
        onTriggered: {
            root.repeatHeldAction();
            holdRepeatTimer.start();
        }
    }

    Timer {
        id: holdRepeatTimer
        interval: 85
        repeat: true
        onTriggered: root.repeatHeldAction()
    }
}
