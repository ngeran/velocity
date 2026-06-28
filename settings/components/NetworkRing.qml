// =============================================================================
// NetworkRing.qml — Segmented Signal Strength Ring (Theme-Aware)
//
// PUBLIC API (unchanged — drop-in replacement):
//   integrityValue : real    0.0–1.0
//   label          : string  optional override label
//   valueText      : string  defaults to "72%"
//
// THEME REACTIVITY:
//   All segment colors bind to Config.ThemeConfig.colors.* Tier-2 tokens.
//   When applyTheme() reassigns the colors object, QML re-evaluates every
//   binding here automatically — no polling, no manual refresh.
//
//   Segment → token mapping:
//     0–20%  CRITICAL  colors.error     (red)
//     20–40% POOR      between error→warning (interpolated via activeColor)
//     40–60% FAIR      colors.warning   (amber)
//     60–80% GOOD      colors.success   (green)
//     80–100% OPTIMAL  colors.secondary (cyan / teal)
//
//   Track ring background:  colors.surfaceContainer
//   Zone label:             colors.textDim (very dim, OLED-safe)
//   Ambient glow:           activeColor at 0.35 opacity
//
// ARCHITECTURE:
//   Canvas context2D draws each arc segment individually, allowing partial
//   fill within a segment and per-segment color without N ShapePath bindings.
//   _animatedValue is driven by NumberAnimation so arc sweeps are smooth.
//   repaintTimer fires requestPaint() at 60fps during the animation.
// =============================================================================

import QtQuick
import Qt5Compat.GraphicalEffects
import "../config" as Config

Item {
    id: ringRoot

    // -------------------------------------------------------------------------
    // PUBLIC API
    // -------------------------------------------------------------------------
    property real   integrityValue: 0.0
    property string label:          ""
    property string valueText:      Math.round(integrityValue * 100) + "%"

    // -------------------------------------------------------------------------
    // THEME TOKENS — live bindings, re-evaluate on every applyTheme() call
    // -------------------------------------------------------------------------
    readonly property color _tError:   Config.ThemeConfig.colors.error     || "#f87171"
    readonly property color _tWarning: Config.ThemeConfig.colors.warning   || "#fbbf24"
    readonly property color _tSuccess: Config.ThemeConfig.colors.success   || "#34d399"
    readonly property color _tOptimal: Config.ThemeConfig.colors.secondary || "#00dce5"
    readonly property color _tTrack:   Config.ThemeConfig.colors.surfaceContainer || "#111111"
    readonly property color _tDim:     Config.ThemeConfig.colors.textDim   || "#808080"

    // Derived: a mid tone between error and warning for the POOR band
    // Qt.tint() blends two colors; we just use the warning at lower brightness
    // for POOR — keeps it visually distinct from FAIR without a new token.
    readonly property color _tPoor: Qt.darker(_tWarning, 1.35)

    // -------------------------------------------------------------------------
    // SEGMENT DEFINITIONS
    // Bound to theme tokens — rebuilds when any token changes.
    // -------------------------------------------------------------------------
    readonly property var segments: [
        { minVal: 0.00, maxVal: 0.20, zone: "CRITICAL" },
        { minVal: 0.20, maxVal: 0.40, zone: "POOR"     },
        { minVal: 0.40, maxVal: 0.60, zone: "FAIR"     },
        { minVal: 0.60, maxVal: 0.80, zone: "GOOD"     },
        { minVal: 0.80, maxVal: 1.00, zone: "OPTIMAL"  },
    ]

    // Color per segment index — kept as a function so it re-reads live tokens
    function segmentColor(index) {
        switch (index) {
            case 0: return ringRoot._tError
            case 1: return ringRoot._tPoor
            case 2: return ringRoot._tWarning
            case 3: return ringRoot._tSuccess
            case 4: return ringRoot._tOptimal
        }
        return "#444444"
    }

    // -------------------------------------------------------------------------
    // ACTIVE STATE — color + zone of the highest filled segment
    // -------------------------------------------------------------------------
    readonly property color activeColor: {
        var f = integrityValue
        if (f <= 0.00) return _tDim
        if (f <= 0.20) return _tError
        if (f <= 0.40) return _tPoor
        if (f <= 0.60) return _tWarning
        if (f <= 0.80) return _tSuccess
        return _tOptimal
    }

    readonly property string activeZone: {
        var f = integrityValue
        if (f <= 0.00) return "—"
        if (f <= 0.20) return "CRITICAL"
        if (f <= 0.40) return "POOR"
        if (f <= 0.60) return "FAIR"
        if (f <= 0.80) return "GOOD"
        return "OPTIMAL"
    }


    // -------------------------------------------------------------------------
    // SMOOTH VALUE ANIMATION
    // -------------------------------------------------------------------------
    property real _animatedValue: 0.0

    Behavior on integrityValue {
        NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
    }

    NumberAnimation {
        id: valueAnim
        target: ringRoot
        property: "_animatedValue"
        duration: 600
        easing.type: Easing.OutCubic
    }

    onIntegrityValueChanged: {
        valueAnim.to = integrityValue
        valueAnim.restart()
    }

    // Repaint when theme tokens change (colors object reassigned by applyTheme)
    on_TErrorChanged:   ringCanvas.requestPaint()
    on_TWarningChanged: ringCanvas.requestPaint()
    on_TSuccessChanged: ringCanvas.requestPaint()
    on_TOptimalChanged: ringCanvas.requestPaint()
    on_TPoorChanged:    ringCanvas.requestPaint()
    on_TTrackChanged:   ringCanvas.requestPaint()

    // -------------------------------------------------------------------------
    // AMBIENT GLOW
    // -------------------------------------------------------------------------
    DropShadow {
        anchors.fill: ringCanvas
        horizontalOffset: 0
        verticalOffset: 0
        radius: 10
        samples: 17
        color: ringRoot.activeColor
        source: ringCanvas
        opacity: 0.35
        Behavior on color { ColorAnimation { duration: 400 } }
    }

    // -------------------------------------------------------------------------
    // CANVAS
    // -------------------------------------------------------------------------
    Canvas {
        id: ringCanvas
        anchors.fill: parent
        antialiasing: true

        Timer {
            id: repaintTimer
            interval: 16
            repeat: true
            running: valueAnim.running
            onTriggered: ringCanvas.requestPaint()
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var W = width, H = height
            var cx = W / 2, cy = H / 2
            var strokeW = Math.max(7, Math.round(W * 0.075))
            var radius  = W / 2 - strokeW - 3

            var nSegs   = ringRoot.segments.length
            var gapDeg  = 3.5
            var segDeg  = (360 - nSegs * gapDeg) / nSegs
            var startDeg = -90

            var val = ringRoot._animatedValue

            for (var i = 0; i < nSegs; i++) {
                var seg      = ringRoot.segments[i]
                var segStart = startDeg + i * (segDeg + gapDeg)
                var segEnd   = segStart + segDeg
                var color    = ringRoot.segmentColor(i)

                // Track arc
                ctx.beginPath()
                ctx.arc(cx, cy, radius,
                    segStart * Math.PI / 180,
                    segEnd   * Math.PI / 180)
                ctx.strokeStyle = ringRoot._tTrack
                ctx.lineWidth   = strokeW
                ctx.lineCap     = "butt"
                ctx.stroke()

                if (val <= seg.minVal) continue

                var fillFrac = (val >= seg.maxVal)
                    ? 1.0
                    : (val - seg.minVal) / (seg.maxVal - seg.minVal)

                var fillEndDeg = segStart + segDeg * fillFrac

                // Glow halo
                ctx.save()
                ctx.globalAlpha = 0.20
                ctx.beginPath()
                ctx.arc(cx, cy, radius,
                    segStart   * Math.PI / 180,
                    fillEndDeg * Math.PI / 180)
                ctx.strokeStyle = color
                ctx.lineWidth   = strokeW + 9
                ctx.lineCap     = "butt"
                ctx.stroke()
                ctx.restore()

                // Filled arc
                ctx.beginPath()
                ctx.arc(cx, cy, radius,
                    segStart   * Math.PI / 180,
                    fillEndDeg * Math.PI / 180)
                ctx.strokeStyle = color
                ctx.lineWidth   = strokeW
                ctx.lineCap     = "butt"
                ctx.stroke()

                // Leading-edge cap dot on partial segment
                if (fillFrac > 0.0 && fillFrac < 1.0) {
                    var capAngle = fillEndDeg * Math.PI / 180
                    var capX = cx + Math.cos(capAngle) * radius
                    var capY = cy + Math.sin(capAngle) * radius

                    ctx.beginPath()
                    ctx.arc(capX, capY, strokeW / 2, 0, Math.PI * 2)
                    ctx.fillStyle = color
                    ctx.fill()

                    ctx.beginPath()
                    ctx.arc(capX, capY, 2.0, 0, Math.PI * 2)
                    ctx.fillStyle = "#ffffff"
                    ctx.globalAlpha = 0.70
                    ctx.fill()
                    ctx.globalAlpha = 1.0
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // CENTER LABEL STACK
    // -------------------------------------------------------------------------
    Column {
        anchors.centerIn: parent
        spacing: 3

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:  ringRoot.valueText
            color: ringRoot.activeColor
            font.pixelSize: Math.round(ringRoot.width * 0.195)
            font.bold:      true
            font.family:    Config.SettingsConfig.fontFamily
            Behavior on color { ColorAnimation { duration: 400 } }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:  ringRoot.activeZone
            color: ringRoot._tDim
            font.pixelSize:   Math.round(ringRoot.width * 0.065)
            font.bold:        true
            font.family:      Config.SettingsConfig.fontFamily
            font.letterSpacing: 1.2
            Behavior on color { ColorAnimation { duration: 400 } }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: ringRoot.label !== ""
            text:    ringRoot.label.toUpperCase()
            color:   Qt.rgba(
                         Qt.color(ringRoot._tDim).r,
                         Qt.color(ringRoot._tDim).g,
                         Qt.color(ringRoot._tDim).b,
                         0.5)
            font.pixelSize:   Math.round(ringRoot.width * 0.055)
            font.bold:        true
            font.family:      Config.SettingsConfig.fontFamily
            font.letterSpacing: 1.5
        }
    }
}
