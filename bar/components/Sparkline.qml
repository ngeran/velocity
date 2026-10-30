// GENERATED from shared/components/Sparkline.qml by tools/sync-shared — do not edit
// =============================================================================
// Sparkline.qml — rolling-value line chart (stroke + low-alpha area fill)
// =============================================================================
// CANONICAL FILE — lives in shared/, synced byte-identical into
//   settings/components/Sparkline.qml   (Core telemetry)
// by tools/sync-shared; drift fails tools/check-shared. Edit here only.
//
// Behaviour re-implemented from omacale's Sparkline (GPL — no code copied):
//   • samples are INDEX-spaced (width/(capacity-1)), right-aligned — the
//     newest point is always at the right edge; the line grows leftward
//     until the window fills, then the oldest falls off
//   • on append the new point starts one step BEYOND the right edge and the
//     whole line GLIDES left one step (slide 1→0) instead of jumping
//   • shownMax eases toward the running max with a min floor, so the
//     vertical scale never twitches on a single spiky sample; a fixed
//     ceiling (valueMax, e.g. 100 for %) pins it instead
//
// Data contract: `samples` = plain numbers, oldest first. Feed history-ring
// shapes ({time,value}) through a .map — see CoreSystemPane's MEMORY block.
// The stroke/fill defaults are deliberately unthemed: this file is synced
// into two roots with different singleton import URIs, so callers MUST pass
// theme colors explicitly (both do).
// OLED doctrine: keep the stroke dim (theme-tinted) and the fill translucent;
// this repaints every sample — never let it sit as a static bright bar.
// =============================================================================

import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property var samples: []          // numbers, oldest → newest
    property int capacity: 130        // hard window; x-spacing is constant
    property color stroke: "#888888"
    property color fill: "transparent"
    property real minFloor: 1         // shownMax never below this
    property real valueMax: 0         // >0 = fixed ceiling (e.g. 100 for %)
    property int slideDuration: 350   // 0 disables the glide
    property int maxEaseDuration: 500

    // ── eased vertical scale ─────────────────────────────────────────────────
    property real shownMax: minFloor
    Behavior on shownMax {
        NumberAnimation { property: "shownMax"; duration: root.maxEaseDuration; easing.type: Easing.OutQuad }
    }

    // ── slide-in on append ───────────────────────────────────────────────────
    // Driven imperatively (not a Behavior): an append glides, a reset snaps —
    // same property, two policies.
    property real slide: 0            // 0 settled · 1 = new point off right edge
    property var _prevTail: undefined
    property int _prevLen: 0
    NumberAnimation {
        id: slideAnim
        target: root; property: "slide"; from: 1; to: 0
        duration: root.slideDuration; easing.type: Easing.OutCubic
    }

    onSamplesChanged: {
        var a = root.samples, n = a.length
        var tail = n > 0 ? a[n - 1] : undefined
        // rescale (pinned when valueMax is set)
        if (root.valueMax > 0) root.shownMax = root.valueMax
        else {
            var m = 0
            for (var i = 0; i < n; i++) if (a[i] > m) m = a[i]
            root.shownMax = Math.max(root.minFloor, m)
        }
        // append: the old tail is still second-to-last, and length grew by
        // one (window filling) OR stayed equal (window full — append drops
        // the oldest) → glide. reset/shrink (or a source switch): snap.
        if (n >= 2 && root._prevTail !== undefined
                && (n === root._prevLen || n === root._prevLen + 1)
                && a[n - 2] === root._prevTail && root.slideDuration > 0) {
            root.slide = 1
            slideAnim.restart()
        } else {
            slideAnim.stop()
            root.slide = 0
        }
        root._prevTail = tail
        root._prevLen = n
    }

    // ── geometry ─────────────────────────────────────────────────────────────
    readonly property real _step: root.capacity > 1 ? root.width / (root.capacity - 1) : 0
    readonly property var _pts: {
        var a = root.samples, n = a.length
        if (n === 0 || root.width < 2 || root.height < 2) return []
        var max = Math.max(root.shownMax, 1e-9)
        var off = root.slide * root._step
        var out = []
        for (var i = 0; i < n; i++) {
            var x = root.width - (n - 1 - i) * root._step + off
            var y = root.height - 0.5 - Math.min(Math.max(a[i] / max, 0), 1) * (root.height - 1)
            out.push(Qt.point(Math.round(x), Math.round(y)))
        }
        return out
    }
    readonly property var _fillPts: {
        var p = root._pts
        if (p.length < 2) return []
        return p.concat([Qt.point(p[p.length - 1].x, root.height + 2),
                         Qt.point(p[0].x, root.height + 2)])
    }

    clip: true   // the gliding-in point spends slideDuration beyond the edge

    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.GeometryRenderer

        ShapePath {
            fillColor: root.fill
            strokeColor: "transparent"
            PathPolyline { path: root._fillPts }
        }
        ShapePath {
            strokeWidth: 1.5
            strokeColor: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: root._pts.length >= 2 ? root._pts : [] }
        }
    }
}
