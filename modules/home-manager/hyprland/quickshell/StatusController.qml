pragma ComponentBehavior: Bound

import QtQml
import Quickshell

Scope {
    id: root

    // Public status facade. UI modules depend on this stable API while each
    // status domain owns its private state and native/command-backed details.
    // System telemetry, connectivity, power (from hypr-shell-status.sh)
    property alias airplaneMode: systemStatus.airplaneMode
    property alias cpuPercent: systemStatus.cpuPercent
    property alias memPercent: systemStatus.memPercent
    property alias tempC: systemStatus.tempC
    property alias brightnessPercent: systemStatus.brightnessPercent
    property alias networkOnline: systemStatus.networkOnline
    property alias networkName: systemStatus.networkName
    property alias networkType: systemStatus.networkType
    property alias vpnOn: systemStatus.vpnOn
    property alias vpnName: systemStatus.vpnName
    property alias vpnType: systemStatus.vpnType
    property alias bluetoothPowered: systemStatus.bluetoothPowered
    property alias bluetoothDevices: systemStatus.bluetoothDevices
    property alias powerProfile: systemStatus.powerProfile
    property alias caffeineManual: systemStatus.caffeineManual

    // Audio (PipeWire, native)
    property alias volumePercent: audio.volumePercent
    property alias volumeText: audio.volumeText
    property alias muted: audio.muted
    // Expose the audio domain object so AudioActions can read the live sink node
    // (and reuse its single PwObjectTracker) rather than re-deriving its own.
    property alias audioStatus: audio

    // Battery (UPower, native)
    property alias batteryPercent: battery.batteryPercent
    property alias batteryReady: battery.batteryReady
    property alias batteryCharging: battery.batteryCharging
    property alias batteryFull: battery.batteryFull
    property alias batteryStatusLabel: battery.batteryStatusLabel

    // Media (MPRIS, native)
    property alias mediaPlayer: media.mediaPlayer
    property alias mediaPlayers: media.mediaPlayers
    property alias selectedPlayerId: media.selectedPlayerId
    property alias mediaStatus: media.mediaStatus
    property alias mediaSource: media.mediaSource
    property alias mediaArtist: media.mediaArtist
    property alias mediaTrackTitle: media.mediaTrackTitle
    property alias mediaAlbumArt: media.mediaAlbumArt
    property alias mediaPosition: media.mediaPosition
    property alias mediaLength: media.mediaLength
    property alias mediaProgress: media.mediaProgress
    property alias mediaHasLength: media.mediaHasLength
    property alias mediaActive: media.mediaActive
    property alias mediaIsMusic: media.mediaIsMusic
    property alias mediaDisplayTitle: media.mediaDisplayTitle

    // Clock (from hypr-shell-timezones.sh)
    property alias clockText: systemStatus.clockText

    // Ingestion handle. UI reads the flat aliases above; the data pipes in
    // shell.qml push raw source data straight to the owning domain object
    // through this alias (e.g. status.systemStatus.updateStatus(data)). Keeping
    // ingestion on the domain object — rather than re-wrapping each setter as a
    // function here — keeps this controller a pure state facade with no extra
    // forwarding layer. Only SystemStatus needs this; the audio/battery/media
    // domains are native services with no command-fed input.
    property alias systemStatus: systemStatus

    AudioStatus { id: audio }
    BatteryStatus { id: battery }
    MediaStatus { id: media }
    SystemStatus { id: systemStatus }
}
