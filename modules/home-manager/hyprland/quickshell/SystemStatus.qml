pragma ComponentBehavior: Bound

import QtQml

QtObject {
    id: root

    // This object mirrors the atomic JSON emitted by hypr-shell-status.sh. Each
    // field is a single raw fact: booleans are booleans, numbers are numbers,
    // and a value that has no source (no sensor, no backlight) is null rather
    // than a sentinel string. Widgets format these at the display edge.

    // Airplane mode is writable: ConnectivityActions sets it optimistically on
    // toggle, then the next status poll confirms it from the rfkill state.
    property bool airplaneMode: false

    // ── Telemetry (raw numbers; widgets append %, °C, etc.) ──────────────
    property int cpuPercent: 0
    property int memPercent: 0
    property var tempC: null               // CPU package °C, or null (no sensor)

    // ── Brightness ─────────────────────────────────────────────────────
    property var brightnessPercent: null   // 0–100, or null when there is no backlight

    // ── Connectivity ───────────────────────────────────────────────────
    property bool networkOnline: false     // has an active default-route link
    property string networkName: ""         // primary connection name ("" when offline)
    property string networkType: ""         // "wifi" | "ethernet" | "" (primary link type)

    // VPN is an overlay on top of the primary link, not a link type of its own.
    property bool vpnOn: false
    property string vpnName: ""              // VPN / WireGuard connection name
    property string vpnType: ""              // "vpn" | "wireguard" | "tun" | ""

    property bool bluetoothPowered: false
    // Connected devices: array of { name, mac, batteryPercent (int|null), icon }.
    property var bluetoothDevices: []

    // ── Power / misc ───────────────────────────────────────────────────
    property string powerProfile: ""        // raw backend profile string (e.g. "balanced")
    property bool caffeineManual: false

    // ── Clock (sourced from hypr-shell-timezones.sh) ─────────────────────
    property string clockText: "Loading"

    function updateStatus(data) {
        // Telemetry — celsius/percent may be null when the source is absent.
        root.cpuPercent = data.cpu.percent;
        root.memPercent = data.memory.usedPercent;
        root.tempC = data.temperature.celsius;
        root.brightnessPercent = data.brightness.percent;

        // Connectivity.
        root.networkOnline = data.network.online;
        root.networkName = data.network.primary.name;
        root.networkType = data.network.primary.type;
        root.vpnOn = data.vpn.on;
        root.vpnName = data.vpn.name;
        root.vpnType = data.vpn.type;
        root.bluetoothPowered = data.bluetooth.powered;
        root.bluetoothDevices = data.bluetooth.devices;

        // Radios / power / misc.
        root.airplaneMode = data.rfkill.airplaneMode;
        root.powerProfile = data.power.profile;
        root.caffeineManual = data.caffeine.manual;
    }

    function updateOsdReadings(brightness) {
        // The OSD polls brightness far faster than the status script; reflect
        // those reads immediately so the slider and OSD stay in sync.
        if (brightness >= 0) {
            root.brightnessPercent = brightness;
        }
    }

    function updateTimezones(data) {
        root.clockText = data.local;
    }
}
