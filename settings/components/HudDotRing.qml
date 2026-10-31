// =============================================================================
// HudDotRing.qml — dot-matrix ring gauge with a Doto numeral core
// =============================================================================
// The cluster's ring instrument, per the Doto reference mock: a circle of
// dots (lit fraction = value, accent on dim-LED track) around a big
// dot-matrix numeral (Doto) with a mono caption underneath — e.g. "23" over
// "GPU · 40°". Pure vector + text; repaints on value/colour/size change only,
// never per frame (OLED/CPU discipline).
// =============================================================================

import QtQuick
import "../config" as Config

Item {
    id: root

    property real value: 0              // 0..100 — lit fraction of the ring
    property string valueText: "0"      // the big Doto numeral inside
    property string caption: ""         // mono caption under the numeral
    property color accent: Config.HudConfig.amber
    property color trackColor: Config.HudConfig.ledDim

    onValueChanged: canvas.requestPaint()
    onAccentChanged: canvas.requestPaint()
    onTrackColorChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            var d = Math.min(width, height)
            if (d <= 24) return
            var cx = width / 2, cy = height / 2
            var r = d / 2 - 6
            var N = 40
            var dotR = Math.max(1.6, d / 68)
            var lit = Math.round(N * Math.max(0, Math.min(100, root.value)) / 100)
            for (var i = 0; i < N; i++) {
                var ang = -Math.PI / 2 + 2 * Math.PI * i / N
                ctx.beginPath()
                ctx.arc(cx + r * Math.cos(ang), cy + r * Math.sin(ang), dotR, 0, 2 * Math.PI)
                ctx.fillStyle = i < lit ? root.accent : root.trackColor
                ctx.fill()
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Math.round(root.height * 0.02)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.valueText
            color: Config.HudConfig.textHi
            font.family: Config.HudConfig.fontDoto
            font.weight: Font.Black
            font.pixelSize: Math.round(root.height * 0.24)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.caption !== ""
            text: root.caption
            color: Config.HudConfig.textMid
            font.family: Config.HudConfig.fontData
            font.pixelSize: Math.max(7, Math.round(root.height * 0.052))
            font.bold: true
            font.letterSpacing: 1.0
        }
    }
}
