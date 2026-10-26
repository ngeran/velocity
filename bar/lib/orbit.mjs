// shared/orbit.mjs — QD-OLED burn-in orbit math (canonical; byte-synced into
// bar/lib/orbit.mjs by tools/sync-shared; drift fails tools/check-shared).
//
// A slow orbit through 9 sub-perceptual offsets (one step per period). x
// moves the content; y only nudges within the strip (a shape with a flat
// screen-edge side should apply x only to stay flush). amp 0 disables.
// Offsets are INTEGERS — a fractional-pixel shift would anti-alias the
// whole strip soft (the half-pixel blur trap).
//
// Consumers: bar/components/BurnOrbit.qml (the shared tick) — styles bind
// their content offsets to `offset`; island imported this same table from
// its own lib before the helper went shared (T20).

var ORBIT = [[0, 0], [1, 0], [2, 1], [1, 1], [0, 1], [-1, 1], [-2, 0], [-1, -1], [1, -1]]

function num(v, d) { var n = Number(v); return isFinite(n) ? n : d }

export function orbitOffset(tick, amp) {
    var a = Math.max(0, Math.min(4, Math.round(num(amp, 2))))
    if (a === 0) return { x: 0, y: 0 }
    var i = ((Math.floor(num(tick, 0)) % ORBIT.length) + ORBIT.length) % ORBIT.length
    var p = ORBIT[i]
    return { x: Math.round(p[0] * a / 2), y: Math.max(-1, Math.min(1, p[1])) }
}
