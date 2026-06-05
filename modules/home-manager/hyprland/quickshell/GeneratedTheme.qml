// Repo-local fallback for the generated theme tokens. Home Manager overwrites
// this file in the built Quickshell config with values from local.theme and
// local.fonts in quickshell.nix. Keep this fallback so the source tree remains
// loadable for local testing and editor/QML tooling.
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property color base:           "#1e1e2e"
    readonly property color surfaceVariant: "#313244"
    readonly property color surfaceHover:   "#3a3c52"
    readonly property color surfaceDeep:    "#15161a"
    readonly property color scrim:          "#000000"
    readonly property color outline:        "#45475a"
    readonly property color text:           "#cdd6f4"
    readonly property color textSecondary:  "#a6adc8"
    readonly property color textDim:        "#6c7086"
    readonly property color primary:        "#b4befe"
    readonly property color secondary:      "#cba6f7"
    readonly property color error:          "#f38ba8"
    readonly property color success:        "#a6e3a1"
    readonly property color warning:        "#f9e2af"
    readonly property color primaryForeground: "#11111b"
    readonly property color secondaryForeground: "#11111b"
    readonly property color errorForeground: "#11111b"
    readonly property color metricCpu:      "#89b4fa"
    readonly property color metricMemory:   "#94e2d5"
    readonly property color metricTemperature: "#fab387"

    readonly property string fontFamily:     "SF Pro Display"
    readonly property string monoFontFamily: "Berkeley Mono"
}
