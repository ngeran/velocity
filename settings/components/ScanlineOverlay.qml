// =============================================================================
// ScanlineOverlay.qml — decorative CRT scanlines (pure visual, no input capture)
// =============================================================================

import QtQuick
import "../config" as Config

Item {
    Canvas {
        anchors.fill: parent
        opacity: Config.ControlConfig.scanlineOpacity
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = "#FFFFFF"
            ctx.lineWidth = 1
            for (var y = 0; y <= height; y += Config.ControlConfig.scanlineSpacing) {
                ctx.beginPath()
                ctx.moveTo(0, y)
                ctx.lineTo(width, y)
                ctx.stroke()
            }
        }
    }
}
