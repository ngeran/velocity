// =============================================================================
// SegmentTrack.qml — stateless segment-value track (J5)
// =============================================================================
// `osdStyle: "segments"` alternative to the continuous OSD/island track: N
// fixed segments, lit count = round(value/100·segments), lit = accent at full
// opacity, unlit = the same accent at dimAlpha (QD-OLED: a dim tint, not a
// bright fill — default 0.35 sits under the ornaments ≤ 0.45 ceiling).
//
// STATELESS (D13): every visual comes in as a property — no singletons, no
// timers, no IO. Steps are deliberately discrete (the segment aesthetic);
// consumers animate around it if they want motion (the island gates that on
// reduceMotion, which a Ui component must not read).
//
//   import qs.Ui            // plugins
//   import "../Ui" as Ui    // bar internals (relative, like ../config etc. —
//                           // duplication is harmless for a stateless type)
//
//   Ui.SegmentTrack { value: 42; segments: 12; accent: …; width: 142; height: 6 }
// =============================================================================
import QtQuick

Item {
    id: root

    // 0..100 — clamped; 100 lights every segment.
    property real value: 0
    // Fixed segment count (the "fixed model"): layout never reflows while a
    // track is on screen.
    property int segments: 12
    property color accent: "#00dce5"
    // Unlit segments: the accent at this opacity (0 = invisible).
    property real dimAlpha: 0.35
    // Gap between segments and their corner radius (0 = the bar's sharp
    // design language; the island passes height/2 for its pill track).
    property int gap: 2
    property real segmentRadius: 0

    readonly property int litCount: Math.round(
        Math.max(0, Math.min(100, root.value)) / 100 * root.segments)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        anchors.fill: parent
        spacing: root.gap

        Repeater {
            model: root.segments

            Rectangle {
                width: (row.width - row.spacing * (root.segments - 1)) / root.segments
                height: row.height
                radius: root.segmentRadius
                color: root.accent
                opacity: index < root.litCount ? 1 : root.dimAlpha
            }
        }
    }
}
