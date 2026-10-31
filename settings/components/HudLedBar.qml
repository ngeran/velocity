// =============================================================================
// HudLedBar.qml — discrete LED segment meter (the mock's 50-tick load bar)
// =============================================================================
// N segments in a row with fixed gaps; the first round(value/100·N) are LIT
// (accent + soft glow), the rest dim. A 2px midpoint tick overlays the center
// (mock's 50% marker). All colors default from HudConfig; consumers may pass
// a tier color (loadTier) as litColor.
// =============================================================================

import QtQuick
import "../config" as Config

Item {
    id: root

    property real value: 0                 // 0..100
    property int segments: 50
    property int midpointIndex: -1         // -1 = no marker
    property color litColor: Config.HudConfig.amber
    property color dimColor: Config.HudConfig.ledDim
    property int segmentGap: 3
    property real glowAlpha: 0.25

    readonly property int litCount: value > 0
        ? Math.max(1, Math.min(segments, Math.round(value / 100 * segments)))
        : 0
    readonly property real segW: segments > 0
        ? (width - (segments - 1) * segmentGap) / segments : 0

    implicitHeight: 12

    Repeater {
        model: root.segments
        delegate: Item {
            x: index * (root.segW + root.segmentGap)
            y: 0
            width: root.segW
            height: root.height
            // glow bleed behind lit segments (mock led-active box-shadow)
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 2
                height: parent.height + 6
                radius: 2
                color: Config.ThemeConfig.tint(root.litColor, root.glowAlpha)
                visible: model.index < root.litCount
                Behavior on visible { enabled: false }
            }
            Rectangle {
                anchors.fill: parent
                radius: 1
                color: model.index < root.litCount ? root.litColor : root.dimColor
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
    }

    // midpoint marker (50% tick) — overlays the flow like the mock's divider
    Rectangle {
        visible: root.midpointIndex >= 0
        x: root.midpointIndex * (root.segW + root.segmentGap) - 1
        y: -1
        width: 2
        height: root.height + 2
        color: Config.HudConfig.textFaint
    }
}
