// CoreGauge.qml — reusable circular utilization gauge (Canvas). value 0..100.

import QtQuick
import "../config" as Config

Canvas {
    id: root
    property real value: 0.0
    property color arcColor: Config.ThemeConfig.colors.secondary

    onPaint: {
        var ctx = getContext("2d"); ctx.reset()
        var cx = width / 2, cy = height / 2
        var r = Math.min(width, height) / 2 - 16
        ctx.lineWidth = 4
        ctx.strokeStyle = Config.ThemeConfig.colors.outlineVariant
        ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.stroke()
        var frac = Math.max(0, Math.min(100, value)) / 100
        ctx.strokeStyle = root.arcColor
        ctx.shadowColor = root.arcColor
        ctx.shadowBlur = 8
        ctx.beginPath(); ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + frac * 2 * Math.PI); ctx.stroke()
        ctx.shadowBlur = 0
    }
    onValueChanged: requestPaint()
    Timer { interval: 1000; repeat: true; running: true; onTriggered: root.requestPaint() }
}
