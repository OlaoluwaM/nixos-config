// This file is the TTY-test fallback. During home-manager switch, Theme.qml
// is generated from local.theme options in quickshell.nix. Edit the preset
// in modules/home-manager/theme.nix instead.
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // ── Catppuccin Mocha color palette ──────────────────────────────────
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

    // ── Fonts ───────────────────────────────────────────────────────────
    readonly property string fontFamily:     "SF Pro Display"
    readonly property string monoFontFamily: "Berkeley Mono"

    // ── Type scale (px) ─────────────────────────────────────────────────
    // The recurring text roles, named so panels/capsules stop hardcoding the
    // same pixel sizes. Values mirror what the UI already used; sizes that
    // appear only once or twice (one-offs) intentionally stay inline rather
    // than inflating this scale.
    readonly property int fontDisplay:   54   // big clock / battery readout
    readonly property int fontTitle:     22   // modal title, secondary readout
    readonly property int fontHeader:    16   // panel section headers
    readonly property int fontMedium:    14   // clock, notification body, emphasis labels
    readonly property int fontBody:      13   // capsule labels, default body
    readonly property int fontCaption:   12   // secondary captions
    readonly property int fontSmall:     11   // smallest labels

    // ── Capsule geometry ────────────────────────────────────────────────
    readonly property int capsuleHeight:        46
    readonly property int capsuleRadius:        10
    readonly property int capsuleButtonSize:    34
    readonly property int capsuleButtonRadius:  8
    readonly property int popoverRadius:        20
    readonly property int cardRadius:           14
    readonly property int trackRadius:          3   // thin slider / progress bars

    // ── Animation durations (ms) ────────────────────────────────────────
    readonly property int animFast:       150
    readonly property int animNormal:     300
    readonly property int animFade:       200

    // ── Easing vocabulary (all Easing.Bezier; pick the curve by motion role) ──
    readonly property int easingType: Easing.Bezier
    // standard — neutral motion: hover, colour fades, value changes (CSS "ease")
    readonly property list<real> easingCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0]
    // decel (ease-out) — entrances: an element appears and settles into place
    readonly property list<real> easingDecel: [0.0, 0.0, 0.2, 1.0, 1.0, 1.0]
    // accel (ease-in) — exits: an element leaves and accelerates away
    readonly property list<real> easingAccel: [0.4, 0.0, 1.0, 1.0, 1.0, 1.0]

    // ── Capsule state helpers ───────────────────────────────────────────
    // Uniform (active, hovered) signature; each responds to the state it needs:
    // fill washes with the accent when active, brightens on hover, border/text
    // shift to the accent when active.
    function capsuleColor(active, hovered) {
        // Active = a popover is open, or a radio/link is live. We wash the base
        // surface with a low-alpha primary tint rather than the solid-primary
        // fill used by the momentary toggles (caffeine/airplane): connectivity
        // is "on" most of the time, so a full accent fill would make the bar
        // loud. The tint reads as "live" while staying subtle; hover deepens it
        // slightly so the cursor still gives feedback. Computed here so every
        // capsule that sets `active` gets the same treatment for free.
        if (active)
            return Qt.tint(surfaceVariant, Qt.rgba(primary.r, primary.g, primary.b, hovered ? 0.26 : 0.18));
        return hovered ? surfaceHover : surfaceVariant;
    }

    function capsuleBorderColor(active, hovered) {
        return active ? primary : outline;
    }

    function capsuleTextColor(active, hovered) {
        return active ? primary : text;
    }

    // ── Active accent gradient (the "live radio/link" capsules: wifi/bt) ──
    // A soft primary→secondary wash that reads as "live" without the loud solid
    // fill of the momentary toggles. The stops tint the surface (rather than
    // using the raw accents) so the wash stays in-palette and gentle; opaque so
    // it composites over the capsule surface, not the transparent bar window.
    // Border and text for these capsules stay on the standard accent helpers
    // (capsuleBorderColor / capsuleTextColor with active = true).
    function capsuleGradientStart() {
        return Qt.tint(surfaceVariant, Qt.rgba(primary.r, primary.g, primary.b, 0.22));
    }
    function capsuleGradientEnd() {
        return Qt.tint(surfaceVariant, Qt.rgba(secondary.r, secondary.g, secondary.b, 0.22));
    }
}
