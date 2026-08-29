// =============================================================================
// CoreSparkline.qml — points-driven rolling time-series plot
// =============================================================================
// Ported from omarchy-system-monitor's Sparkline.qml (minus its mirrored
// network mode). Callers bind `points` to a service-owned history ring buffer
// ({time, value} objects, oldest first — see services/History.js). This canvas
// owns NO timer and NO buffer of its own, so history survives panel
// close/reopen (HudSpark's buffer died with the tab's Loader) and multiple
// views can share one series.
//
//   line + soft fill (fillEnabled) grow up from the bottom edge; gridLevels
//   draw faint rules at fractions of full scale so an idle chart still reads
//   as "lots of headroom" rather than an empty box. fixedMaximum > 0 pins the
//   vertical scale so the caller can label the chart with the same number it
//   was drawn against; <= 0 auto-scales to the window peak × 1.12.
//
// Repaints only on points/colour/size change — never per frame (OLED/CPU
// discipline, same as HudGauge).
// =============================================================================

import QtQuick
import "../config" as Config
import "../services/History.js" as History

Canvas {
    id: root

    property var points: []
    property color lineColor: Config.ThemeConfig.colors.accent
    // Fill derives from lineColor at paint time (NOT a stale copy), so a theme
    // swap retints line + fill together.
    property bool fillEnabled: true
    property color gridColor: Config.ThemeConfig.tint(Config.ThemeConfig.colors.text, 0.10)
    property var gridLevels: [0.25, 0.5, 0.75]
    property bool dashed: false
    property real lineWidth: 1.5
    property real fixedMaximum: -1
    property int windowMs: 120000

    antialiasing: true
    onPointsChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onGridColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onFixedMaximumChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        if (width <= 0 || height <= 0 || !points || points.length < 2) return

        var newest = Number(points[points.length - 1].time)
        if (!(newest > 0)) return
        var oldest = newest - windowMs

        var maximum = fixedMaximum
        if (!(maximum > 0)) {
            maximum = History.peakValue(points) * 1.12
            if (!(maximum > 0)) maximum = 1
        }

        // Axis at the bottom edge; values grow upward.
        var axis = height - 1
        var span = height - 2

        function pointX(p) {
            return Math.max(0, Math.min(width, (Number(p.time) - oldest) * width / windowMs))
        }
        function pointY(p) {
            var v = Number(p.value)
            if (!isFinite(v) || v < 0) v = 0
            return axis - Math.min(1, v / maximum) * span
        }

        ctx.strokeStyle = gridColor
        ctx.lineWidth = 1
        for (var g = 0; g < gridLevels.length; g++) {
            var level = Math.max(0, Math.min(1, Number(gridLevels[g])))
            var gy = Math.round(axis - level * span) + 0.5
            ctx.beginPath()
            ctx.moveTo(0, gy)
            ctx.lineTo(width, gy)
            ctx.stroke()
        }

        if (fillEnabled) {
            ctx.beginPath()
            ctx.moveTo(pointX(points[0]), axis)
            for (var i = 0; i < points.length; i++)
                ctx.lineTo(pointX(points[i]), pointY(points[i]))
            ctx.lineTo(pointX(points[points.length - 1]), axis)
            ctx.closePath()
            ctx.fillStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.16)
            ctx.fill()
        }

        if (ctx.setLineDash) ctx.setLineDash(dashed ? [3, 3] : [])
        ctx.beginPath()
        ctx.moveTo(pointX(points[0]), pointY(points[0]))
        for (var j = 1; j < points.length; j++)
            ctx.lineTo(pointX(points[j]), pointY(points[j]))
        ctx.strokeStyle = lineColor
        ctx.lineWidth = lineWidth
        ctx.stroke()
        if (ctx.setLineDash) ctx.setLineDash([])
    }
}
