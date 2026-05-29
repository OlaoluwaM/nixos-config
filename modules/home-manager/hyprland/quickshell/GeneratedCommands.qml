pragma Singleton
pragma ComponentBehavior: Bound

import QtQml
import Quickshell

Singleton {
    id: root

    // Nix fills these placeholders with store paths during Home Manager
    // generation. Native Quickshell services handle audio, media, and battery.
    readonly property string shellCommand: "@SHELL_COMMAND@"
    readonly property string catCommand: "@CAT_COMMAND@"
    readonly property string awkCommand: "@AWK_COMMAND@"
    readonly property string trCommand: "@TR_COMMAND@"
    readonly property string statusScript: "@STATUS_SCRIPT@"
    readonly property string timezoneScript: "@TIMEZONE_SCRIPT@"
    readonly property string networkCommand: "@NETWORK_COMMAND@"
    readonly property string bluetoothCommand: "@BLUETOOTH_COMMAND@"
    readonly property string powerCommand: "@POWER_COMMAND@"
    readonly property string rebootCommand: "@REBOOT_COMMAND@"
    readonly property string powerProfileCommand: "@POWER_PROFILE_COMMAND@"
    readonly property string caffeineCommand: "@CAFFEINE_COMMAND@"
    readonly property string brightnessCommand: "@BRIGHTNESS_COMMAND@"
    readonly property string lockCommand: "@LOCK_COMMAND@"
    readonly property string sleepCommand: "@SLEEP_COMMAND@"
    readonly property string rfkillCommand: "@RFKILL_COMMAND@"
    readonly property string logoutCommand: "@LOGOUT_COMMAND@"
    readonly property string notifySendCommand: "@NOTIFY_SEND_COMMAND@"
}
