// Shared design system for the shell. Nix-owned color and font tokens come from
// GeneratedTheme.qml; static geometry, animation, and helper functions live here.
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // ── Generated color palette ─────────────────────────────────────────
    readonly property color base:           GeneratedTheme.base
    readonly property color surfaceVariant: GeneratedTheme.surfaceVariant
    readonly property color surfaceHover:   GeneratedTheme.surfaceHover
    readonly property color surfaceDeep:    GeneratedTheme.surfaceDeep
    readonly property color scrim:          GeneratedTheme.scrim
    readonly property color outline:        GeneratedTheme.outline
    readonly property color text:           GeneratedTheme.text
    readonly property color textSecondary:  GeneratedTheme.textSecondary
    readonly property color textDim:        GeneratedTheme.textDim
    readonly property color primary:        GeneratedTheme.primary
    readonly property color secondary:      GeneratedTheme.secondary
    readonly property color error:          GeneratedTheme.error
    readonly property color success:        GeneratedTheme.success
    readonly property color warning:        GeneratedTheme.warning
    readonly property color primaryForeground: GeneratedTheme.primaryForeground
    readonly property color secondaryForeground: GeneratedTheme.secondaryForeground
    readonly property color errorForeground: GeneratedTheme.errorForeground
    readonly property color metricCpu:      GeneratedTheme.metricCpu
    readonly property color metricMemory:   GeneratedTheme.metricMemory
    readonly property color metricTemperature: GeneratedTheme.metricTemperature

    // ── Generated fonts ─────────────────────────────────────────────────
    readonly property string fontFamily:     GeneratedTheme.fontFamily
    readonly property string monoFontFamily: GeneratedTheme.monoFontFamily

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

    // ── Popover geometry and motion ────────────────────────────────────
    readonly property int popoverScreenInset:   12
    readonly property int popoverGap:           8
    readonly property int popoverFrameRadius:   16
    readonly property int popoverPadding:       24
    readonly property int popoverCompactPadding: 20
    readonly property int popoverContentGap:    12
    readonly property int popoverSectionGap:    16
    readonly property int popoverCompactWidth:  360
    readonly property int popoverStandardWidth: 460
    readonly property int popoverWideWidth:     700
    readonly property int popoverMotionDistanceOpen: 6
    readonly property int popoverMotionDistanceClose: 4
    readonly property int popoverMotionDuration: 150
    // A 6px blur offset 6px down has no top reach and a 12px bottom reach.
    readonly property int popoverShadowBlur: 6
    readonly property int popoverShadowOffsetY: 6
    readonly property int popoverShadowBottomExtent: 12
    readonly property int popoverBottomClearance: popoverShadowBottomExtent
        + Math.max(popoverMotionDistanceOpen, popoverMotionDistanceClose)
    readonly property color popoverShadowColor: Qt.rgba(scrim.r, scrim.g, scrim.b, 0.34)

    // ── Bar geometry and surfaces ───────────────────────────────────────
    // These tokens belong to the top bar only. Popovers retain the generic
    // capsule geometry above; shell.qml and Popovers.qml share the position
    // tokens so the popup edge continues to track the rail.
    readonly property int barTopMargin:       8
    readonly property int barOuterMargin:     8
    readonly property int barHeight:          48
    readonly property int barExclusiveZone:   56
    readonly property int barWindowHeight:    82
    readonly property int barPadding:         6
    readonly property int barGroupPadding:    4
    readonly property int barGroupGap:        4
    readonly property int barSectionGap:      6
    readonly property int barControlHeight:   36
    readonly property int barControlRadius:   9
    readonly property int barRailRadius:      14
    readonly property int barIconSize:        15
    readonly property int barLabelMaxWidth:   88
    readonly property int barFontBody:        12
    readonly property int barFontCaption:     11

    readonly property color barRailColor: Qt.tint(base, Qt.rgba(surfaceVariant.r, surfaceVariant.g, surfaceVariant.b, 0.42))
    readonly property color barWidgetColor: Qt.tint(surfaceVariant, Qt.rgba(base.r, base.g, base.b, 0.22))
    readonly property color barAccentGradientStart: Qt.tint(barWidgetColor, Qt.rgba(primary.r, primary.g, primary.b, 0.24))
    readonly property color barAccentGradientEnd: Qt.tint(barWidgetColor, Qt.rgba(secondary.r, secondary.g, secondary.b, 0.24))

    // ── Animation durations (ms) ────────────────────────────────────────
    readonly property int animFast:       150
    readonly property int animNormal:     300
    readonly property int animFade:       200
    readonly property int animPulse:      550   // slow attention pulse (e.g. low-battery blink)
    readonly property int animSpring:     400   // playful overshoot move (see spring easing below)

    // ── Easing vocabulary (all Easing.Bezier; pick the curve by motion role) ──
    readonly property int easingType: Easing.Bezier
    // standard — neutral motion: hover, colour fades, value changes (CSS "ease")
    readonly property list<real> easingCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0]
    // decel (ease-out) — entrances: an element appears and settles into place
    readonly property list<real> easingDecel: [0.0, 0.0, 0.2, 1.0, 1.0, 1.0]
    // accel (ease-in) — exits: an element leaves and accelerates away
    readonly property list<real> easingAccel: [0.4, 0.0, 1.0, 1.0, 1.0, 1.0]
    // spring — overshoots past the target then settles. Uses Qt's built-in Back
    // easing (not the bezier vocabulary above) because a single cubic bezier
    // can't express an overshoot beyond the end value. Pair with animSpring.
    readonly property int easingSpringType: Easing.OutBack
    readonly property real springOvershoot: 1.4

    // ── Capsule state helpers ───────────────────────────────────────────
    function barControlColor(active, hovered, urgent) {
        if (active)
            return Qt.tint(barWidgetColor, Qt.rgba(primary.r, primary.g, primary.b, hovered ? 0.30 : 0.22));
        if (urgent)
            return Qt.tint(barWidgetColor, Qt.rgba(error.r, error.g, error.b, hovered ? 0.26 : 0.18));
        return hovered ? surfaceHover : barWidgetColor;
    }

    function barControlTextColor(active, hovered, urgent) {
        if (active)
            return primary;
        if (urgent)
            return error;
        return hovered ? text : textSecondary;
    }

    // Uniform (active, hovered) signature; each responds to the state it needs:
    // fill washes with the accent when active, brightens on hover, and text
    // shifts to the accent when active.
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

    function capsuleTextColor(active, hovered) {
        return active ? primary : text;
    }

    // ── Active accent gradient (the "live radio/link" capsules: wifi/bt) ──
    // A soft primary→secondary wash that reads as "live" without the loud solid
    // fill of the momentary toggles. The stops tint the surface (rather than
    // using the raw accents) so the wash stays in-palette and gentle; opaque so
    // it composites over the capsule surface, not the transparent bar window.
    // Text for these capsules stays on the standard accent helper.
    function capsuleGradient() {
        return {
            start: Qt.tint(surfaceVariant, Qt.rgba(primary.r, primary.g, primary.b, 0.22)),
            end: Qt.tint(surfaceVariant, Qt.rgba(secondary.r, secondary.g, secondary.b, 0.22))
        };
    }

    function osdGradient(value) {
        // Make the OSD fill brighter as the value rises. OSD values are
        // percentages, so clamp them to 0-100 and normalize that to 0.0-1.0.
        // minAlpha is the accent mix at 0%; maxAlpha is the accent mix at 100%.
        // curve controls when the fill brightens: 1.0 is linear, above 1.0
        // stays dim longer, below 1.0 brightens sooner.
        let minAlpha = 0.22;
        let maxAlpha = 0.95;
        let curve = 1.0;
        let clamped = Math.max(0, Math.min(100, value));
        let normalizedValue = Math.pow(clamped / 100, curve);
        let alpha = minAlpha + normalizedValue * (maxAlpha - minAlpha);
        return {
            start: Qt.tint(surfaceVariant, Qt.rgba(primary.r, primary.g, primary.b, alpha)),
            end: Qt.tint(surfaceVariant, Qt.rgba(secondary.r, secondary.g, secondary.b, alpha))
        };
    }
}
