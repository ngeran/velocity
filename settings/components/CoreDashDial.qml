// =============================================================================
// CoreDashDial.qml — tachometer dial: segmented gradient arc + cyan needle
// =============================================================================
// HUD rebuild of the old 240° boost dial: 180° sweep, per-segment arc colored
// cyan → amber across the gauge (mock's gradient tach), dot ticks outside,
// cyan needle + hub. Pure vector, no images. Repaints on value/colour/size
// change only — never per frame (OLED/CPU discipline).
// =============================================================================

import QtQuick
import "../config" as Config

Canvas {
    id: root

    property real value: 0             // 0..100
    property color accent: Config.HudConfig.cyan    // arc start
    property color hotColor: Config.HudConfig.amber // arc end
    property color trackColor: Config.HudConfig.ledDim
    property color needleColor: Config.HudConfig.cyan

    antialiasing: true
    onValueChanged: requestPaint()
    onAccentChanged: requestPaint()
    onHotColorChanged: requestPaint()
    onTrackColorChanged: requestPaint()
    onNeedleColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        if (width <= 0 || height <= 0) return

        var cx = width / 2
        var cy = height * 0.90
        var r = Math.min(width / 2 - 14, height * 0.82)
        if (r <= 10) return
        var START = 180, SWEEP = 180        // left → over the top → right
        var SEGS = 40
        var frac = Math.max(0, Math.min(100, value)) / 100
        var lit = Math.round(SEGS * frac)
        function rad(d) { return d * Math.PI / 180 }
        function px(ang, rr) { return cx + rr * Math.cos(rad(ang)) }
        function py(ang, rr) { return cy - rr * Math.sin(rad(ang)) }
        function mix(a, b, t) {
            return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                           a.b + (b.b - a.b) * t, 1)
        }

        // Segmented arc: each lit segment picks its gradient stop; the rest
        // stay ledDim. 1° gaps read as the mock's ticked tach ring.
        ctx.lineWidth = 4
        ctx.lineCap = "butt"
        for (var i = 0; i < SEGS; i++) {
            var a0 = START - SWEEP * i / SEGS
            var a1 = START - SWEEP * (i + 1) / SEGS
            ctx.strokeStyle = i < lit ? mix(accent, hotColor, i / (SEGS - 1)) : trackColor
            ctx.beginPath()
            // inset both ends 0.6° for the gap
            ctx.arc(cx, cy, r, rad(a0 - 0.6), rad(a1 + 0.6), true)
            ctx.stroke()
        }

        // Dot ticks outside the arc (every 12.5% — 9 dots, ends brighter)
        ctx.fillStyle = trackColor
        for (var t = 0; t <= 8; t++) {
            var ang = START - SWEEP * t / 8
            ctx.beginPath()
            ctx.arc(px(ang, r + 8), py(ang, r + 8), 1.4, 0, 2 * Math.PI)
            ctx.fill()
        }

        // Needle + hub
        var na = START - SWEEP * frac
        ctx.strokeStyle = needleColor
        ctx.lineWidth = 2
        ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(px(na, r - 12), py(na, r - 12)); ctx.stroke()
        ctx.fillStyle = needleColor
        ctx.beginPath(); ctx.arc(cx, cy, 3, 0, 2 * Math.PI); ctx.fill()
        ctx.fillStyle = Config.HudConfig.wellDeep
        ctx.beginPath(); ctx.arc(cx, cy, 1.4, 0, 2 * Math.PI); ctx.fill()
    }
}
