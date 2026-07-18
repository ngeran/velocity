// =============================================================================
// HudGauge.qml — radial arc gauge (Core section redesign primitive)
// =============================================================================
// Canvas ring: a dim full-circle track + an accent arc sweeping clockwise from
// 12 o'clock by (value/max). Center shows the value+unit, label beneath. Used
// for CPU/GPU package temps on the Overview's Thermal Dynamics module.
//
// Repaints ONLY on value/accent/size change — never per frame (OLED + CPU).
// Colours are live ThemeConfig tokens; pass `accent: tempTier(temp)` for a
// cool→warm→hot severity tint.
// =============================================================================

import QtQuick
import "../config" as Config

Item {
    id: root
    property real value: 0
    property real max: 100
    property color accent: Config.ThemeConfig.colors.secondary
    property string label: ""
    property string unit: "°"
    property int size: 96

    width: size; height: size
    readonly property real _frac: Math.max(0, Math.min(1, root.max > 0 ? root.value / root.max : 0))

    Canvas {
        id: canv
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var w = width, h = height
            var cx = w / 2, cy = h / 2
            var r = Math.max(4, Math.min(w, h) / 2 - 6)
            var start = -Math.PI / 2

            // track ring
            ctx.strokeStyle = Config.ThemeConfig.colors.outlineVariant.toString()
            ctx.lineWidth = 5
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.stroke()

            // value arc
            if (root._frac > 0) {
                ctx.strokeStyle = root.accent.toString()
                ctx.lineCap = "round"
                ctx.lineWidth = 5
                ctx.beginPath()
                ctx.arc(cx, cy, r, start, start + root._frac * Math.PI * 2)
                ctx.stroke()
            }
        }
        Component.onCompleted: canv.requestPaint()
    }

    // Repaint only when the inputs actually change.
    Connections { target: root; function onValueChanged() { canv.requestPaint() } }
    Connections { target: root; function onAccentChanged() { canv.requestPaint() } }
    Connections { target: canv; function onWidthChanged() { canv.requestPaint() } }
    Connections { target: canv; function onHeightChanged() { canv.requestPaint() } }

    Column {
        anchors.centerIn: parent
        spacing: 1
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(root.value) + root.unit
            color: root.accent
            font.family: Config.SettingsConfig.fontFamily
            font.pixelSize: 22; font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.label.length > 0
            text: root.label
            color: Config.ThemeConfig.colors.textDim
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 8; font.letterSpacing: 1
        }
    }
}
