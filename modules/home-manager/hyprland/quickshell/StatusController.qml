pragma ComponentBehavior: Bound

import QtQml

QtObject {
    id: root

    property bool airplaneMode: false

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

    readonly property bool mediaActive: root.mediaStatus === "Playing" || root.mediaStatus === "Paused"
    readonly property string mediaDisplayTitle:
        root.mediaArtist.length > 0 && root.mediaTrackTitle.length > 0
            ? root.mediaArtist + " — " + root.mediaTrackTitle
            : root.mediaTrackTitle

    function isUnavailable(value) {
        return value === "" || value === "--" || value === "N/A" || value === "Unavailable";
    }

    function updateStatus(data) {
        root.cpuText = data.cpu + "%";
        root.memText = data.mem + "%";
        root.tempText = root.isUnavailable(data.temp) ? "N/A" : data.temp + "°C";
        root.volumeText = data.volume;
        root.muted = data.muted === "true";
        root.brightnessText = data.brightness;
        root.batteryText = data.battery;
        root.batteryHours = data.batteryHours || "--";
        root.batteryMinutes = data.batteryMinutes || "--";
        root.networkText = data.network;
        root.vpnText = data.vpn;
        root.bluetoothText = data.bluetooth;
        root.bluetoothDevice = data.bluetoothDevice || "";
        root.powerProfileText = data.powerProfile;
        root.mediaStatus = data.mediaStatus;
        root.mediaTitle = data.mediaTitle;
        root.mediaArtist = data.mediaArtist || "";
        root.mediaTrackTitle = data.mediaTrackTitle || data.mediaTitle || "No media";
        root.mediaAlbumArt = data.mediaAlbumArt || "";
        root.mediaPosition = data.mediaPosition || "0:00";
        root.mediaLength = data.mediaLength || "0:00";
    }

    function updateOsdReadings(volume, isMuted, brightness) {
        if (volume >= 0) {
            root.volumeText = volume + "%";
            root.muted = isMuted;
        }
        if (brightness >= 0) {
            root.brightnessText = brightness + "%";
        }
    }

    function updateTimezones(data) {
        root.clockText = data.local;
        root.localTime = data.local;
        root.birminghamTime = data.birmingham;
        root.lagosTime = data.lagos;
        root.sanFranciscoTime = data.sanfrancisco;
    }
}
