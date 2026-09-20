// =============================================================================
// RyokuPixel.qml — 8×8 1-bit dingbat from a string grid (ryoku ui/Pixel port)
// =============================================================================
// String rows of 0/1 paint once on a Canvas — no assets, no shaders. Ink
// follows the live theme; a color change repaints.
// =============================================================================

import QtQuick
import "../../config" as Config

Canvas {
    id: px

    property var glyph: []              // 8 strings of 8 chars ("0"/"1")
    property color ink: Config.ThemeConfig.colors.textDim
    property real inkOpacity: 0.6
    property real cellScale: 1.25       // 8 * 1.25 = 10px

    width: 8 * cellScale
    height: 8 * cellScale
    antialiasing: false

    onInkChanged: requestPaint()
    onGlyphChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.opacity = inkOpacity
        ctx.fillStyle = ink
        for (var y = 0; y < glyph.length && y < 8; y++) {
            var row = String(glyph[y])
            for (var x = 0; x < row.length && x < 8; x++) {
                if (row.charAt(x) === "1")
                    ctx.fillRect(x * cellScale, y * cellScale, cellScale, cellScale)
            }
        }
    }
}
