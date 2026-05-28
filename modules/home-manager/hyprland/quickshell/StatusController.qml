pragma ComponentBehavior: Bound

import QtQml
import Quickshell

Scope {
    id: root

    // Public status facade. UI modules depend on this stable API while each
    // status domain owns its private state and native/command-backed details.
    property alias airplaneMode: systemStatus.airplaneMode
    property alias clockText: systemStatus.clockText
    property alias cpuText: systemStatus.cpuText
    property alias memText: systemStatus.memText
    property alias tempText: systemStatus.tempText
    property alias volumePercent: audio.volumePercent
    property alias volumeText: audio.volumeText
    property alias muted: audio.muted
    property alias brightnessText: systemStatus.brightnessText
    property alias powerProfileText: systemStatus.powerProfileText
    property alias batteryPercent: battery.batteryPercent
    property alias batteryCharging: battery.batteryCharging
    property alias batteryFull: battery.batteryFull
    property alias batteryText: battery.batteryText
    property alias batteryHours: battery.batteryHours
    property alias batteryMinutes: battery.batteryMinutes
    property alias batteryStatusLabel: battery.batteryStatusLabel
    property alias networkText: systemStatus.networkText
    property alias vpnText: systemStatus.vpnText
    property alias bluetoothText: systemStatus.bluetoothText
    property alias bluetoothDevice: systemStatus.bluetoothDevice
    property alias mediaPlayer: media.mediaPlayer
    property alias mediaStatus: media.mediaStatus
    property alias mediaTitle: media.mediaTitle
    property alias mediaArtist: media.mediaArtist
    property alias mediaTrackTitle: media.mediaTrackTitle
    property alias mediaAlbumArt: media.mediaAlbumArt
    property alias mediaPosition: media.mediaPosition
    property alias mediaLength: media.mediaLength
    property alias mediaActive: media.mediaActive
    property alias mediaDisplayTitle: media.mediaDisplayTitle
    property alias localTime: systemStatus.localTime
    property alias birminghamTime: systemStatus.birminghamTime
    property alias lagosTime: systemStatus.lagosTime
    property alias sanFranciscoTime: systemStatus.sanFranciscoTime

    function updateStatus(data) {
        systemStatus.updateStatus(data);
    }

    function updateOsdReadings(brightness) {
        systemStatus.updateOsdReadings(brightness);
    }

    function updateTimezones(data) {
        systemStatus.updateTimezones(data);
    }

    AudioStatus { id: audio }
    BatteryStatus { id: battery }
    MediaStatus { id: media }
    SystemStatus { id: systemStatus }
}
