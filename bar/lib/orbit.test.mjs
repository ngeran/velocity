// orbit.test.mjs — burn-in orbit math (assertion port of the island.test.mjs
// orbit block; the canonical table lives in shared/orbit.mjs).
import { strict as assert } from "node:assert"
import { orbitOffset } from "./orbit.mjs"

const ok = (name, fn) => { fn(); console.log("ok —", name) }

ok("orbit: deterministic, wraps, bounded by amp", () => {
    const seen = new Set()
    for (let t = 0; t < 27; t++) {
        const o = orbitOffset(t, 2)
        assert.ok(Math.abs(o.x) <= 2 && Math.abs(o.y) <= 1, `bounded at ${t}`)
        seen.add(`${o.x},${o.y}`)
    }
    assert.ok(seen.size >= 6, "orbit should visit several positions")
    assert.deepEqual(orbitOffset(0, 2), orbitOffset(9, 2))
    assert.deepEqual(orbitOffset(-1, 2), orbitOffset(8, 2))
})

ok("orbit: amp 0 disables", () => assert.deepEqual(orbitOffset(5, 0), { x: 0, y: 0 }))

ok("orbit: x-only consumer still moves (strip contract)", () => {
    const xs = new Set()
    for (let t = 0; t < 9; t++) xs.add(orbitOffset(t, 2).x)
    assert.ok(xs.size >= 3, "x should visit several columns for strip orbiting")
})
