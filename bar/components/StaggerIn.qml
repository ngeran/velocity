// =============================================================================
// StaggerIn.qml — staggered list reveal (ryoku Entrance port, trimmed)
// =============================================================================
// Wrap a delegate: on creation, each item waits index*stride (capped at
// maxDelay) then fades/lifts in — lists reveal as a cascade instead of a
// single pop. reduceMotion collapses to instant (stride 0 → revealed at once).
//
// Delegate-reuse safe (ListView recycles): the Timer arms on CREATION only —
// an index shift (new item prepended) never re-animates existing delegates;
// the new delegate enters at its own small delay. Layout-safe: scale+opacity
// only (ryoku used a Translate lift to keep childrenRect honest; scale
// achieves the same visual without touching geometry).
//
// Usage:  delegate: StaggerIn { index: model.index;  NotificationToastCard {} }
// =============================================================================

import QtQuick
import "../config" as Config

Item {
    id: stag

    property int index: 0
    property int stride: 40          // ms per position
    property int maxDelay: 240       // cap so long columns stay under ~1/4s
    readonly property bool instant: Config.MotionConfig.dur(stride) === 0

    // Single-content sizing: the wrapper is the delegate root, so it must
    // adopt the wrapped item's implicit size (and let the item fill it).
    // holder is a PLAIN Item — its implicit size never derives from its
    // children, so read the content child's implicit size directly (the
    // single-content contract makes children[0] the wrapped item). Binding
    // these to holder.implicit* offered height 0 and collapsed every list
    // this wrapped (delegates stacked on one spot).
    default property alias content: holder.data
    readonly property var _content: holder.children.length > 0 ? holder.children[0] : null
    implicitWidth: _content ? _content.implicitWidth : 0
    implicitHeight: _content ? _content.implicitHeight : 0
    width: implicitWidth
    height: implicitHeight

    property bool revealed: false

    Timer {
        interval: stag.instant
                 ? 0
                 : Math.min(stag.index * Config.MotionConfig.dur(stag.stride),
                            Config.MotionConfig.dur(stag.maxDelay))
        running: true
        repeat: false
        onTriggered: stag.revealed = true
    }

    Item {
        id: holder
        width: stag.width
        height: stag.height

        opacity: stag.revealed ? 1 : 0
        scale: stag.revealed ? 1 : 0.98

        Behavior on opacity { NumberAnimation { duration: Config.MotionConfig.flap } }
        Behavior on scale { NumberAnimation { duration: Config.MotionConfig.move; easing.type: Config.MotionConfig.ease } }
    }
}
