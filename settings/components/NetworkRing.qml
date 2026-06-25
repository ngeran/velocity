// =============================================================================
// components/NetworkRing.qml
// Circular Gauge / Ring Graph — Signal Integrity Visualizer
//
// USAGE:
//   UI.NetworkRing {
//       width: 160; height: 160
//       integrityValue: 0.92    // 0.0 – 1.0 maps to 0° – 360°
//       label: "INTEGRITY"
//   }
//
// ARCHITECTURE:
//   Two ShapePath arcs are stacked in a single Shape:
//     1. trackArc  — full 360° background ring (dark fill, always visible)
//     2. valueArc  — partial arc driven by integrityValue (accent color)
//
//   Shape.layer.enabled bakes the vector paths into a GPU texture after the
//   first paint, preventing per-frame path recalculation on animation ticks.
//   layer.samples: 4 enables 4× MSAA for smooth arc edges on QD-OLED.
//
// SVG EQUIVALENCE:
//   HTML used: stroke-dasharray="440" stroke-dashoffset derived from value.
//   QML uses:  PathAngleArc sweepAngle = integrityValue * 360
//   Both produce identical visual output; QML's is GPU-accelerated natively.
// =============================================================================

import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import "." as UI
import "../config" as Config

Item {
    id: ringRoot

    // -------------------------------------------------------------------------
    // PUBLIC API
    // -------------------------------------------------------------------------
    property real   integrityValue: 0.0   // Bind to network probe output: 0.0–1.0
    property string label:          ""    // Optional ring label (e.g. "SIGNAL")
    property string valueText:      Math.round(integrityValue * 100) + "%"

    // Smooth animation on value changes — avoids jarring jumps on poll ticks
    Behavior on integrityValue {
        NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
    }

    // -------------------------------------------------------------------------
    // RING CANVAS — GPU-composited vector shape
    // -------------------------------------------------------------------------
    Shape {
        id: shapeCanvas
        anchors.fill: parent

        // Bake the rendered paths to a GPU texture after first draw.
        // Prevents path recalculation every frame during animations.
        layer.enabled:  true
        layer.samples:  4   // 4× MSAA — smooth edges on high-DPI OLED panels

        // ----- TRACK ARC (background ring — always full 360°) ----------------
        ShapePath {
            id: trackArc
            strokeColor: UI.Colors.surfaceContainer
            strokeWidth: 8
            fillColor:   "transparent"
            capStyle:    ShapePath.FlatCap

            PathAngleArc {
                centerX:    ringRoot.width  / 2
                centerY:    ringRoot.height / 2
                radiusX:    (ringRoot.width  / 2) - 8   // Inset by half strokeWidth
                radiusY:    (ringRoot.height / 2) - 8
                startAngle: 0
                sweepAngle: 360
            }
        }

        // ----- VALUE ARC (active fill — driven by integrityValue) ------------
        ShapePath {
            id: valueArc
            strokeColor: Config.ThemeConfig.colors.secondary
            strokeWidth: 8
            fillColor:   "transparent"
            // SquareCap gives a sharp terminal edge — matches the bento aesthetic.
            // Use RoundCap if you prefer soft arc endpoints.
            capStyle:    ShapePath.SquareCap

            PathAngleArc {
                centerX:    ringRoot.width  / 2
                centerY:    ringRoot.height / 2
                radiusX:    (ringRoot.width  / 2) - 8
                radiusY:    (ringRoot.height / 2) - 8
                startAngle: -90   // 12 o'clock start — matches CSS conic-gradient convention
                sweepAngle: ringRoot.integrityValue * 360
            }
        }
    }

    // -------------------------------------------------------------------------
    // CENTER LABEL STACK — percentage + optional label text
    // -------------------------------------------------------------------------
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 2

        Text {
            Layout.alignment: Qt.AlignHCenter
            text:             ringRoot.valueText
            color:            UI.Colors.primary
            font.pixelSize:   Math.round(ringRoot.width * 0.18)  // Scale with ring size
            font.bold:        true
            font.family:      "monospace"
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible:          ringRoot.label !== ""
            text:             ringRoot.label
            color:            UI.Colors.textMuted
            font.pixelSize:   9
            font.family:      "monospace"
            font.letterSpacing: 1.5
        }
    }
}
