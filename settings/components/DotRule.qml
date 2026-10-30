// GENERATED from shared/components/DotRule.qml by tools/sync-shared — do not edit
// =============================================================================
// DotRule.qml — dot-matrix divider (P6.2, canonical — synced copy)
// =============================================================================
// A single row of round dots on transparent black. Replaces 1 px hairlines in
// overlays and cards (QD-OLED law: no static strokes — dots at ≤ ~3 % relative
// luminance read as texture, not as a line; see 00-rules quality bar).
//
// Dots are distributed edge-to-edge (the glyph dotted-progress look): the
// first and last dot sit flush with the rule's ends, the remainder share the
// gap. CANONICAL SOURCE: shared/components/DotRule.qml — bar/components/ and
// settings/components/ hold byte-identical copies (tools/sync-shared). Shared
// components stay host-agnostic (D13): the COLOR comes from the consumer —
// pass ThemeConfig.colors.outlineVariant (or another ≤3 %-luminance token);
// the default is the glyph ramp hairline grey. Accent belongs only on
// transient states, never on a resting rule.
//
//   DotRule { width: 320; dotColor: Config.ThemeConfig.colors.outlineVariant }
//
// Static content: repaints only on width/pitch/dotSize/color change.
// =============================================================================

import QtQuick

Canvas {
    id: rule

    // Center-to-center spacing at rest; real spacing stretches evenly so the
    // rule always meets both edges (pitch is the density request, not a grid).
    property real pitch: 6
    property real dotSize: 2
    property color dotColor: "#1c1c1c"

    implicitHeight: dotSize
    visible: width > 0 && height > 0

    onWidthChanged: requestPaint()
    onPitchChanged: requestPaint()
    onDotSizeChanged: requestPaint()
    onDotColorChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        ctx.fillStyle = String(dotColor)
        var r = dotSize / 2
        var span = Math.max(0, width - dotSize)
        var n = Math.floor(span / pitch) + 1
        var gap = n > 1 ? span / (n - 1) : 0
        for (var i = 0; i < n; i++) {
            ctx.beginPath()
            ctx.arc(r + i * gap, r, r, 0, Math.PI * 2)
            ctx.fill()
        }
    }
}
