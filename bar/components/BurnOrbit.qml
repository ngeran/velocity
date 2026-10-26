// =============================================================================
// BurnOrbit.qml — shared QD-OLED burn-in tick (T20)
// =============================================================================
// One 30-second heartbeat that steps a slow orbit through the sub-perceptual
// offsets of lib/orbit.mjs (one step per `periodSecs`, default 3 min). Every
// bar style hosts one inside its window and binds its content offsets to
// `offset` — no static pixel column sits long enough to burn. The window's
// own black fill never needs to move (off pixels can't burn); only content.
//
// `stepped()` fires on every heartbeat so a host can piggyback its own idle
// accounting (island feeds its rest-state dim clock from it — the dim
// CURVE itself stays island-specific on purpose; dimming strip content is a
// UX decision, not doctrine, and the strips don't do it).
//
// Offsets are integers — never fractional (the half-pixel blur trap).
// Gate: `active` — strips bind Config.BarConfig.stripBurnGuard; amp 0 (or
// active false) pins offset to {0,0}.
// =============================================================================

import QtQuick
import "../lib/orbit.mjs" as Orbit

Item {
    id: guard

    property bool active: true
    property int amp: 2
    property int periodSecs: 180
    readonly property int tick: _ticks * (periodSecs / 30)
    readonly property var offset: Orbit.orbitOffset(tick, active ? amp : 0)

    property int _ticks: 0
    signal stepped()

    Timer {
        interval: 30000
        repeat: true
        running: guard.active
        onTriggered: {
            guard._ticks++
            guard.stepped()
        }
    }
}
