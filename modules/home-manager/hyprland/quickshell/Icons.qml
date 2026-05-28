pragma Singleton

import QtQuick

QtObject {

    // SVG path data keyed by icon name. Each value is the inner elements
    // of a 24x24 SVG with stroke-based rendering.
    readonly property var paths: ({
        battery:          '<path d="M 22 14 L 22 10"/><rect x="2" y="6" width="16" height="12" rx="2"/>',
        batteryCharging:  '<path d="m11 7-3 5h4l-3 5"/><path d="M14.856 6H16a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-2.935"/><path d="M22 14v-4"/><path d="M5.14 18H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h2.936"/>',
        bluetooth:        '<path d="m7 7 10 10-5 5V2l5 5L7 17"/>',
        bluetoothOff:        '<path d="m17 17-5 5V12l-5 5"/><path d="m2 2 20 20"/><path d="M14.5 9.5 17 7l-5-5v4.5"/>',
        brightness:       '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/>',
        brightnessOff:    '<path d="M2 2l20 20M12 6a6 6 0 0 1 5.66 8.01M8.34 8.34A6 6 0 0 0 12 18M12 2v2M20 12h2M4.93 4.93l1.41 1.41M2 12h2"/>',
        close:            '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
        coffee:           '<path d="M10 2v2"/><path d="M14 2v2"/><path d="M16 8a1 1 0 0 1 1 1v8a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4V9a1 1 0 0 1 1-1h14a4 4 0 1 1 0 8h-1"/><path d="M6 2v2"/>',
        cpu:              '<path d="M12 20v2"/><path d="M12 2v2"/><path d="M17 20v2"/><path d="M17 2v2"/><path d="M2 12h2"/><path d="M2 17h2"/><path d="M2 7h2"/><path d="M20 12h2"/><path d="M20 17h2"/><path d="M20 7h2"/><path d="M7 20v2"/><path d="M7 2v2"/><rect x="4" y="4" width="16" height="16" rx="2"/><rect x="8" y="8" width="8" height="8" rx="1"/>',
        left:             '<path d="M15 18l-6-6 6-6"/>',
        memory:           '<path d="M12 12v-2"/><path d="M12 18v-2"/><path d="M16 12v-2"/><path d="M16 18v-2"/><path d="M2 11h1.5"/><path d="M20 18v-2"/><path d="M20.5 11H22"/><path d="M4 18v-2"/><path d="M8 12v-2"/><path d="M8 18v-2"/><rect x="2" y="6" width="20" height="10" rx="2"/>',
        music:            '<path d="M9 18V5l10-2v13M9 18a3 3 0 1 1-2-2.83M19 16a3 3 0 1 1-2-2.83"/>',
        network:          '<path d="M12 20h.01"/><path d="M2 8.82a15 15 0 0 1 20 0"/><path d="M5 12.859a10 10 0 0 1 14 0"/><path d="M8.5 16.429a5 5 0 0 1 7 0"/>',
        networkOff:       '<path d="M12 20h.01"/><path d="M8.5 16.429a5 5 0 0 1 7 0"/><path d="M5 12.859a10 10 0 0 1 5.17-2.69"/><path d="M19 12.859a10 10 0 0 0-2.007-1.523"/><path d="M2 8.82a15 15 0 0 1 4.177-2.643"/><path d="M22 8.82a15 15 0 0 0-11.288-3.764"/><path d="m2 2 20 20"/>',
        next:             '<path d="M5 5l8 7-8 7V5zM17 5v14"/>',
        notifications:    '<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4"/>',
        notificationsOff: '<path d="M13.73 21a2 2 0 0 1-3.46 0M18.63 13A18.5 18.5 0 0 1 18 8a6 6 0 0 0-8.6-5.4M6.26 6.26A6 6 0 0 0 6 8c0 7-3 7-3 9h14M3 3l18 18"/>',
        pause:            '<path d="M8 5v14M16 5v14"/>',
        play:             '<path d="M8 5v14l11-7-11-7z"/>',
        power:            '<path d="M12 2v10M18.36 6.64a9 9 0 1 1-12.72 0"/>',
        previous:         '<path d="M19 5l-8 7 8 7V5zM7 5v14"/>',
        quick:            '<path d="M12 8a4 4 0 1 1 0 8 4 4 0 0 1 0-8z"/><path d="M12 2v3M12 19v3M4.22 4.22l2.12 2.12M17.66 17.66l2.12 2.12M2 12h3M19 12h3M4.22 19.78l2.12-2.12M17.66 6.34l2.12-2.12"/>',
        right:            '<path d="M9 18l6-6-6-6"/>',
        temp:             '<path d="M14 4v10.54a4 4 0 1 1-4 0V4a2 2 0 0 1 4 0Z"/>',
        tray:             '<path d="M12 17v4"/><path d="m14.305 7.53.923-.382"/><path d="m15.228 4.852-.923-.383"/><path d="m16.852 3.228-.383-.924"/><path d="m16.852 8.772-.383.923"/><path d="m19.148 3.228.383-.924"/><path d="m19.53 9.696-.382-.924"/><path d="m20.772 4.852.924-.383"/><path d="m20.772 7.148.924.383"/><path d="M22 13v2a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h7"/><path d="M8 21h8"/><circle cx="18" cy="6" r="3"/>',
        volume:           '<path d="M4 9v6h4l5 4V5L8 9H4zM17 9a4 4 0 0 1 0 6M19.5 6.5a8 8 0 0 1 0 11"/>',
        volumeMuted:      '<path d="M4 9v6h4l5 4V5L8 9H4zM18 9l4 4M22 9l-4 4"/>',
        vpn:              '<path d="M12 3l7 3v5c0 5-3 8-7 10-4-2-7-5-7-10V6l7-3z"/><path d="M9 12h6M12 9v6"/>',
        vpnOff:           '<path d="M12 3l7 3v5c0 1.5-.27 2.86-.8 4.07M15.2 18.7A14.2 14.2 0 0 1 12 21c-4-2-7-5-7-10V6l2.6-1.1M3 3l18 18"/>',
        lock:             '<rect x="5" y="11" width="14" height="11" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
        sleep:            '<path d="M17 18a5 5 0 0 0-10 0M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>',
        refresh:          '<path d="M1 4v6h6M23 20v-6h-6"/><path d="M20.49 9A9 9 0 0 0 5.64 5.64L1 10M23 14l-4.64 4.36A9 9 0 0 1 3.51 15"/>',
        airplane:         '<path d="M21 16v-2l-8-5V3.5a1.5 1.5 0 0 0-3 0V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5z"/>',
        bolt:             '<path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/>',
        gauge:            '<circle cx="12" cy="14" r="8"/><path d="M12 14l3.5-3.5"/><path d="M12 8v1"/>',
        keyboard:         '<rect x="2" y="6" width="20" height="12" rx="2"/><path d="M6 10h.01M10 10h.01M14 10h.01M18 10h.01M8 14h8"/>',
        leaf:             '<path d="M11 20A7 7 0 0 1 9.8 6.9C11 4 13 3 17 3c-.8 6-3.3 10-6 13v4"/><path d="M7 16l3.5-3.5"/>',
        logout:           '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/>'
    })

    // Build a data-URI SVG for the given icon name and stroke color.
    function iconSource(name, color) {
        let body = paths[name] || "";
        let svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="'
            + color + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
            + body + '</svg>';
        return "data:image/svg+xml;utf8," + encodeURIComponent(svg);
    }
}
