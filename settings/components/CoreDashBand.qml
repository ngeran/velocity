// =============================================================================
// CoreDashBand.qml — LED-matrix load band (systemricer-style instrument strip)
// =============================================================================
// One sample per LED column, oldest left → newest right, each column rising as
// quantized LED blocks. Empty headroom shows the dim track matrix so an idle
// band still reads as a live instrument. Tier colour comes from ThemeConfig at
// paint time, so a theme swap retints on repaint (trackColor change triggers).
// Owns NO timer and NO buffer — repaints on points/colour/size change only.
// =============================================================================

import QtQuick
import "../config" as Config

Canvas {
    id: root

    property var points: []            // [{time, value}] oldest-first (History.js)
    property int columns: 48
    property real ledSize: 6
    property real ledGap: 2
    property int windowMs: 120000
    property color trackColor: Config.ThemeConfig.tint(Config.ThemeConfig.colors.text, 0.08)

    antialiasing: false
    onPointsChanged: requestPaint()
    onTrackColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        if (width <= 0 || height <= 0) return

        var cell = ledSize + ledGap
        var rows = Math.max(1, Math.floor((height + ledGap) / cell))
        var colW = width / columns
        var n = points ? points.length : 0

        for (var c = 0; c < columns; c++) {
            var x = Math.round(c * colW)
            var w = Math.max(1, Math.floor(colW) - ledGap)
            var v = 0
            if (n > 0) {
                var idx = n - columns + c          // newest sample at the right edge
                if (idx >= 0) v = Math.max(0, Math.min(100, Number(points[idx].value) || 0))
            }
            var lit = Math.round(v / 100 * rows)
            var col = Config.ThemeConfig.tierColor(v, 50, 85)
            for (var r = 0; r < rows; r++) {
                var y = Math.round(height - (r + 1) * cell + ledGap)
                ctx.fillStyle = r < lit ? col : trackColor
                ctx.fillRect(x, y, w, ledSize)
            }
        }
    }
}
