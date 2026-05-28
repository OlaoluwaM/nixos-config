pragma Singleton
pragma ComponentBehavior: Bound

import QtQml

QtObject {
    id: root

    readonly property string statusScript: "@STATUS_SCRIPT@"
    readonly property string timezoneScript: "@TIMEZONE_SCRIPT@"
    readonly property string vicinaeCommand: "@VICINAE_COMMAND@"
    readonly property string networkCommand: "@NETWORK_COMMAND@"
    readonly property string bluetoothCommand: "@BLUETOOTH_COMMAND@"
    readonly property string powerCommand: "@POWER_COMMAND@"
    readonly property string rebootCommand: "@REBOOT_COMMAND@"
    readonly property string powerProfileCommand: "@POWER_PROFILE_COMMAND@"
    readonly property string pamixerCommand: "@PAMIXER_COMMAND@"
    readonly property string brightnessCommand: "@BRIGHTNESS_COMMAND@"
    readonly property string playerctlCommand: "@PLAYERCTL_COMMAND@"
    readonly property string lockCommand: "@LOCK_COMMAND@"
    readonly property string sleepCommand: "@SLEEP_COMMAND@"
    readonly property string refreshCommand: "@REFRESH_COMMAND@"
    readonly property string rfkillCommand: "@RFKILL_COMMAND@"
    readonly property string logoutCommand: "@LOGOUT_COMMAND@"
    readonly property string notifySendCommand: "@NOTIFY_SEND_COMMAND@"
}
