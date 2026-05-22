pragma Singleton

import QtQuick

QtObject {

    // SVG path data keyed by icon name. Each value is the inner elements
    // of a 24x24 SVG with stroke-based rendering.
    readonly property var paths: ({
        battery:          '<rect x="3" y="7" width="16" height="10" rx="2"/><path d="M21 11v2"/>',
        batteryCharging:  '<rect x="3" y="7" width="16" height="10" rx="2"/><path d="M21 11v2M12 8l-3 5h4l-2 4 4-6h-4l1-3z"/>',
        bluetooth:        '<path d="M7 7l10 10-5 5V2l5 5L7 17"/>',
        brightness:       '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/>',
        brightnessOff:    '<path d="M2 2l20 20M12 6a6 6 0 0 1 5.66 8.01M8.34 8.34A6 6 0 0 0 12 18M12 2v2M20 12h2M4.93 4.93l1.41 1.41M2 12h2"/>',
        close:            '<path d="M18 6L6 18M6 6l12 12"/>',
        cpu:              '<rect x="7" y="7" width="10" height="10" rx="2"/><path d="M9 1v3M15 1v3M9 20v3M15 20v3M1 9h3M1 15h3M20 9h3M20 15h3M10 10h4v4h-4z"/>',
        left:             '<path d="M15 18l-6-6 6-6"/>',
        memory:           '<rect x="4" y="7" width="16" height="10" rx="2"/><path d="M7 7V4M11 7V4M15 7V4M17 7V4M7 20v-3M11 20v-3M15 20v-3M17 20v-3M8 11h8"/>',
        music:            '<path d="M9 18V5l10-2v13M9 18a3 3 0 1 1-2-2.83M19 16a3 3 0 1 1-2-2.83"/>',
        network:          '<path d="M5 12.5a10 10 0 0 1 14 0M8.5 16a5 5 0 0 1 7 0M12 20h.01"/>',
        networkOff:       '<path d="M5 12.5a10 10 0 0 1 8.5-2.8M17 11a10 10 0 0 1 2 1.5M8.5 16a5 5 0 0 1 5.5-.9M12 20h.01M3 3l18 18"/>',
        next:             '<path d="M5 5l8 7-8 7V5zM17 5v14"/>',
        notifications:    '<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4"/>',
        notificationsOff: '<path d="M13.73 21a2 2 0 0 1-3.46 0M18.63 13A18.5 18.5 0 0 1 18 8a6 6 0 0 0-8.6-5.4M6.26 6.26A6 6 0 0 0 6 8c0 7-3 7-3 9h14M3 3l18 18"/>',
        pause:            '<path d="M8 5v14M16 5v14"/>',
        play:             '<path d="M8 5v14l11-7-11-7z"/>',
        power:            '<path d="M12 2v10M18.36 6.64a9 9 0 1 1-12.72 0"/>',
        previous:         '<path d="M19 5l-8 7 8 7V5zM7 5v14"/>',
        quick:            '<path d="M12 8a4 4 0 1 1 0 8 4 4 0 0 1 0-8z"/><path d="M12 2v3M12 19v3M4.22 4.22l2.12 2.12M17.66 17.66l2.12 2.12M2 12h3M19 12h3M4.22 19.78l2.12-2.12M17.66 6.34l2.12-2.12"/>',
        right:            '<path d="M9 18l6-6-6-6"/>',
        temp:             '<path d="M14 14.76V5a2 2 0 0 0-4 0v9.76a4 4 0 1 0 4 0z"/>',
        tray:             '<path d="M4 5h6v6H4zM14 5h6v6h-6zM4 15h6v4H4zM14 15h6v4h-6z"/>',
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
