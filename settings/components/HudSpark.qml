// =============================================================================
// HudSpark.qml — self-contained live sparkline (Core section redesign primitive)
// =============================================================================
// Owns a rolling sample buffer + a Timer that pushes the bound `value` every
// `intervalMs` (default 1s) and repaints. onPaint draws a faint gridline set, a
// stroked polyline through the buffer scaled to `max`, and a low-alpha area
// fill. Caller just binds `value` to a live number (e.g. cpuUsage) — no
// external sampling wiring needed.
//
// Repaints only on each sample tick and on accent/size change. Colours are live
// ThemeConfig tokens.
// =============================================================================

import QtQuick
import "../config" as Config

Item {
    id: root
    property real value: 0
    property real max: 100
    property color accent: Config.ThemeConfig.colors.secondary
    property int intervalMs: 1000
    property int maxSamples: 60
    property var buffer: []

    height: 40

    Canvas {
        id: canv
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var w = width, h = height
            ctx.clearRect(0, 0, w, h)

            // faint horizontal gridlines
            ctx.strokeStyle = Config.ThemeConfig.colors.border.toString()
            ctx.globalAlpha = 0.4
            ctx.lineWidth = 1
            for (var g = 1; g <= 2; g++) {
                var gy = h * g / 3
                ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(w, gy); ctx.stroke()
            }
            ctx.globalAlpha = 1

            var data = root.buffer
            if (data.length < 2) return

            var accent = root.accent.toString()
            var max = root.max > 0 ? root.max : 100
            var pts = []
            for (var i = 0; i < data.length; i++) {
                var x = (i / (data.length - 1)) * w
                var v = Math.max(0, Math.min(max, data[i]))
                var y = h - (v / max) * h
                pts.push([x, y])
            }

            // area fill
            ctx.beginPath()
            ctx.moveTo(pts[0][0], h)
            for (var p = 0; p < pts.length; p++) ctx.lineTo(pts[p][0], pts[p][1])
            ctx.lineTo(pts[pts.length - 1][0], h)
            ctx.closePath()
            ctx.fillStyle = accent
            ctx.globalAlpha = 0.12
            ctx.fill()
            ctx.globalAlpha = 1

            // stroke
            ctx.strokeStyle = accent
            ctx.lineWidth = 1.5
            ctx.beginPath()
            ctx.moveTo(pts[0][0], pts[0][1])
            for (var q = 1; q < pts.length; q++) ctx.lineTo(pts[q][0], pts[q][1])
            ctx.stroke()
        }
        Component.onCompleted: canv.requestPaint()
    }

    Timer {
        interval: root.intervalMs; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var s = root.buffer.slice()
            s.push(root.value)
            if (s.length > root.maxSamples) s.shift()
            root.buffer = s
            canv.requestPaint()
        }
    }

    Connections { target: root; function onAccentChanged() { canv.requestPaint() } }
    Connections { target: canv; function onWidthChanged() { canv.requestPaint() } }
    Connections { target: canv; function onHeightChanged() { canv.requestPaint() } }
}
