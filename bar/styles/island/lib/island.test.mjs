// island.test.mjs — state machine, geometry and burn-in math of styles/island.
import { strict as assert } from "node:assert"
import {
    REST, GLANCE, ACTIVITY, PANEL,
    nextState, targetSize, cornerRadius, filletRadius, panelBudget,
    orbitOffset, restAlpha, fitScale, FIT_SCALE_MIN
} from "./island.mjs"

let n = 0
function ok(name, fn) { fn(); n++; console.log("  ok " + name) }

// ── state machine ──
ok("rest + hoverIn → glance", () => assert.equal(nextState(REST, "hoverIn", {}), GLANCE))
ok("glance + hoverOut → rest", () => assert.equal(nextState(GLANCE, "hoverOut", {}), REST))
ok("glance + hoverOut with a live activity → activity", () =>
    assert.equal(nextState(GLANCE, "hoverOut", { hasActivity: true }), ACTIVITY))
ok("any + present → panel", () => {
    for (const s of [REST, GLANCE, ACTIVITY, PANEL]) assert.equal(nextState(s, "present", {}), PANEL)
})
ok("panel ignores hover changes", () => {
    assert.equal(nextState(PANEL, "hoverOut", {}), PANEL)
    assert.equal(nextState(PANEL, "hoverIn", {}), PANEL)
})
ok("panel + dismiss while hovered → glance", () =>
    assert.equal(nextState(PANEL, "dismiss", { hovered: true }), GLANCE))
ok("panel + dismiss away → rest", () => assert.equal(nextState(PANEL, "dismiss", {}), REST))
ok("activity only blooms from rest, never interrupts a panel", () => {
    assert.equal(nextState(REST, "activity", {}), ACTIVITY)
    assert.equal(nextState(PANEL, "activity", {}), PANEL)
    assert.equal(nextState(GLANCE, "activity", {}), GLANCE)
})
ok("activityEnd settles by hover", () => {
    assert.equal(nextState(ACTIVITY, "activityEnd", {}), REST)
    assert.equal(nextState(ACTIVITY, "activityEnd", { hovered: true }), GLANCE)
})
ok("unknown event keeps state", () => assert.equal(nextState(GLANCE, "nope", {}), GLANCE))

// ── geometry ──
const base = { barH: 30, padX: 16, panelPad: 14, margin: 12 }
ok("rest = clock + padding, floored at the pill minimum", () => {
    assert.deepEqual(targetSize(REST, { ...base, restW: 60 }), { w: 96, h: 30 })
    assert.deepEqual(targetSize(REST, { ...base, restW: 10 }), { w: 96, h: 30 })  // 30*3.2
})
ok("glance grows to the sections, stays one row tall", () =>
    assert.deepEqual(targetSize(GLANCE, { ...base, glanceW: 900, screenW: 3840 }), { w: 932, h: 30 }))
ok("glance clamps to the screen minus margins (1366)", () =>
    assert.equal(targetSize(GLANCE, { ...base, glanceW: 2000, screenW: 1366 }).w, 1342))
ok("panel sizes to content + panelPad", () =>
    assert.deepEqual(targetSize(PANEL, { ...base, panelW: 520, panelH: 260, screenW: 3840, screenH: 2160 }),
                     { w: 548, h: 288 }))
ok("panel height clamps to maxHFrac of the screen", () =>
    assert.equal(targetSize(PANEL, { ...base, panelW: 300, panelH: 2000, screenW: 1366, screenH: 768 }).h,
                 Math.round(768 * 0.8)))
ok("activity can be taller than the bar", () =>
    assert.deepEqual(targetSize(ACTIVITY, { ...base, activityW: 300, activityH: 44 }), { w: 332, h: 44 }))
ok("junk metrics never yield NaN", () => {
    const s = targetSize(PANEL, { barH: "x", panelW: undefined, panelH: null })
    assert.ok(isFinite(s.w) && isFinite(s.h) && s.w >= 1 && s.h >= 18)
})
ok("panelBudget leaves room for padding and margins", () => {
    assert.deepEqual(panelBudget({ ...base, screenW: 3840, screenH: 2160 }), { w: 3788, h: 1700 })
    assert.deepEqual(panelBudget({ ...base }), { w: -1, h: -1 })
})

ok("radius: one-row island is a full pill", () => assert.equal(cornerRadius(REST, 30, 30), 15))
ok("radius: panel caps at 0.8 * barH", () => assert.equal(cornerRadius(PANEL, 300, 30), 24))
ok("radius: tall activity caps like a panel", () => assert.equal(cornerRadius(ACTIVITY, 60, 30), 24))
ok("fillet scales with the bar and clamps 6..12", () => {
    assert.equal(filletRadius(18), 6)
    assert.equal(filletRadius(30), 10)
    assert.equal(filletRadius(64), 12)
})

// ── burn-in guard ──
ok("orbit: deterministic, wraps, bounded by amp", () => {
    const seen = new Set()
    for (let t = 0; t < 18; t++) {
        const o = orbitOffset(t, 2)
        assert.ok(Math.abs(o.x) <= 2 && Math.abs(o.y) <= 1)
        seen.add(o.x + "," + o.y)
    }
    assert.ok(seen.size >= 6, "orbit should visit several positions")
    assert.deepEqual(orbitOffset(0, 2), orbitOffset(9, 2))
    assert.deepEqual(orbitOffset(-1, 2), orbitOffset(8, 2))
})
ok("orbit: amp 0 disables", () => assert.deepEqual(orbitOffset(5, 0), { x: 0, y: 0 }))
ok("rest alpha: dimmed active, dimmer idle, full when expanded", () => {
    assert.equal(restAlpha(REST, 0, {}), 0.82)
    assert.equal(restAlpha(REST, 90000, {}), 0.45)
    assert.equal(restAlpha(GLANCE, 999999, {}), 1)
    assert.equal(restAlpha(REST, 999999, { guard: false }), 0.82)
})

// ── scale-led transitions ──
ok("fitScale: room to spare → exactly 1 (no upscale on overshoot)", () =>
    assert.equal(fitScale(800, 400, 300, 200, 6, 0), 1))
ok("fitScale: island half the content width → ~0.5 floored at min", () =>
    assert.equal(fitScale(160, 400, 300, 200, 6, 0), FIT_SCALE_MIN))
ok("fitScale: tracks the tighter axis incl. reserved strip", () =>
    assert.equal(fitScale(1000, 30 + 12 + 160, 300, 200, 6, 30), 0.8))
ok("fitScale: unknown content size → 1", () => {
    assert.equal(fitScale(100, 30, 0, 0, 6, 0), 1)
    assert.equal(fitScale(100, 30, undefined, null, 6, 0), 1)
})

console.log("island.test.mjs: OK (" + n + " assertions)")
