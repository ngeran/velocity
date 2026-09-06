// =============================================================================
// CoreDashDial.qml — semicircular boost dial with needle (systemricer-style)
// =============================================================================
// 240° sweep arc, tick ring, needle + hub. Pure vector, no images. Repaints on
// value/colour/size change only — never per frame (OLED/CPU discipline).
// =============================================================================

import QtQuick
import "../config" as Config

Canvas {
    id: root

    property real value: 0             // 0..100
    property color accent: Config.ThemeConfig.colors.primary
    property color trackColor: Config.ThemeConfig.tint(Config.ThemeConfig.colors.text, 0.22)

    antialiasing: true
    onValueChanged: requestPaint()
    onAccentChanged: requestPaint()
    onTrackColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        if (width <= 0 || height <= 0) return

        var cx = width / 2
        var cy = height * 0.88
        var r = Math.min(width / 2 - 8, height * 0.80)
        if (r <= 10) return
        var START = 210, SWEEP = 240                       // 210° → -30°, over the top
        var frac = Math.max(0, Math.min(100, value)) / 100
        function rad(d) { return d * Math.PI / 180 }
        function px(ang, rr) { return cx + rr * Math.cos(rad(ang)) }
        function py(ang, rr) { return cy - rr * Math.sin(rad(ang)) }

        // Track arc + active arc
        ctx.lineWidth = 3
        ctx.strokeStyle = trackColor
        ctx.beginPath(); ctx.arc(cx, cy, r, rad(START), rad(START - SWEEP), true); ctx.stroke()
        if (frac > 0) {
            ctx.strokeStyle = accent
            ctx.beginPath(); ctx.arc(cx, cy, r, rad(START), rad(START - SWEEP * frac), true); ctx.stroke()
        }

        // Tick ring (21 ticks, every 5th longer)
        ctx.lineWidth = 1.5
        for (var t = 0; t <= 20; t++) {
            var ang = START - SWEEP * t / 20
            var major = t % 5 === 0
            ctx.strokeStyle = major ? trackColor : Qt.lighter(trackColor, 1.4)
            ctx.beginPath()
            ctx.moveTo(px(ang, r - (major ? 9 : 5)), py(ang, r - (major ? 9 : 5)))
            ctx.lineTo(px(ang, r - 3), py(ang, r - 3))
            ctx.stroke()
        }

        // Needle + hub
        var na = START - SWEEP * frac
        ctx.strokeStyle = accent
        ctx.lineWidth = 2
        ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(px(na, r - 14), py(na, r - 14)); ctx.stroke()
        ctx.fillStyle = accent
        ctx.beginPath(); ctx.arc(cx, cy, 3, 0, 2 * Math.PI); ctx.fill()
    }
}
