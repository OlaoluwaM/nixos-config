pragma ComponentBehavior: Bound

import QtQml

QtObject {
    id: root

    property bool airplaneMode: false

    property string clockText: "Loading"
    property string cpuText: "..."
    property string memText: "..."
    property string tempText: "..."
    property string brightnessText: "N/A"
    property string powerProfileText: "Unavailable"
    property string networkText: "Offline"
    property string vpnText: "Off"
    property string bluetoothText: "Off"
    property string bluetoothDevice: ""
    property string localTime: "Loading"
    property string birminghamTime: "..."
    property string lagosTime: "..."
    property string sanFranciscoTime: "..."

    function isUnavailable(value) {
        return value === "" || value === "--" || value === "N/A" || value === "Unavailable";
    }

    function updateStatus(data) {
        root.cpuText = data.cpu + "%";
        root.memText = data.mem + "%";
        root.tempText = root.isUnavailable(data.temp) ? "N/A" : data.temp + "°C";
        root.brightnessText = data.brightness;
        root.networkText = data.network;
        root.vpnText = data.vpn;
        root.bluetoothText = data.bluetooth;
        root.bluetoothDevice = data.bluetoothDevice || "";
        root.powerProfileText = data.powerProfile;
    }

    function updateOsdReadings(brightness) {
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
