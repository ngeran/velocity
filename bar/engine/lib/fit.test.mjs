// fit.test.mjs — overflow planning: stages, hide order, center clamp, widths.
import { strict as assert } from "node:assert"
import { planFit, DEFAULT_PRIORITY } from "./fit.mjs"

let n = 0
function ok(name, fn) { fn(); n++; console.log("  ok " + name) }

const c = (id, w, wc, p) => (wc === undefined && p === undefined ? { id, w }
    : p === undefined ? { id, w, wc } : { id, w, wc, p })

// The real bar at 26px, logical px: logo+dots left, clock center, 11 right.
function fixture() {
    return {
        pad: 8,
        gap: 8,
        left: [c("velocity.logo", 24, 24, 90), c("velocity.workspaces", 110, 110, 95)],
        center: [c("velocity.clock", 280, 70, 50)],
        right: [c("velocity.notifications", 30, 30, 90), c("nikos.keyboard", 78),
                c("nikos.example", 84), c("nikos.timezones", 30), c("randazraik.xray", 30),
                c("velocity.network", 26), c("velocity.bluetooth", 26), c("velocity.volume", 26),
                c("velocity.privacy", 26, 26, 60), c("velocity.logs", 26, 26, 30),
                c("velocity.settings", 26, 26, 20)],
    }
}

ok("cells: junk dropped, wc clamped into [0,w], p defaults to 50", () => {
    assert.equal(DEFAULT_PRIORITY, 50)
    const p = planFit({ width: 5000, left: [null, { w: 10 }, { id: "", w: 10 }, { id: "a", w: -5 }, { id: "b", w: 40, wc: 99 }, { id: "d", w: 30, p: 7.4 }] })
    assert.deepEqual(p.maps.left, { b: "full", d: "full" })
    const p2 = planFit({ width: 10, left: [{ id: "b", w: 40, wc: 99 }, { id: "d", w: 30, p: 7.4 }] })
    assert.equal(p2.maps.left.b, "collapsed")   // wc clamped to w: not compactable, hidden directly
    assert.deepEqual(p2.hidden.sort(), ["b", "d"])
})

ok("wide window: full stage, dead-center ideal", () => {
    const p = planFit(Object.assign({ width: 3440 }, fixture()))
    assert.equal(p.stage, "full")
    assert.equal(p.fits, true)
    assert.deepEqual(p.hidden, [])
    assert.deepEqual(p.compacted, [])
    assert.equal(p.centerX, (3440 - 280) / 2)
    assert.equal(p.widths.left, 24 + 8 + 110)   // 2 cells + 1 gap
    assert.equal(p.widths.right, 30 + 78 + 84 + 30 + 30 + 26 * 6 + 8 * 10)
})

ok("slack hysteresis: 930 stays compact, 934 returns to full", () => {
    // full 926 needs width-8; compact 726 needs width
    assert.equal(planFit(Object.assign({ width: 930, slack: 8 }, fixture())).stage, "compact")
    assert.equal(planFit(Object.assign({ width: 934, slack: 8 }, fixture())).stage, "full")
    assert.equal(planFit(Object.assign({ width: 934, slack: 0 }, fixture())).stage, "full")
})

ok("compact stage: only wc<w cells shrink, maps report it", () => {
    const p = planFit(Object.assign({ width: 800 }, fixture()))
    assert.equal(p.stage, "compact")
    assert.deepEqual(p.compacted, ["velocity.clock"])
    assert.deepEqual(p.hidden, [])
    assert.equal(p.maps.center["velocity.clock"], "compact")
    assert.equal(p.maps.left["velocity.logo"], "full")
    assert.equal(p.widths.center, 70)
    // center clamped against the right rail, no overlap
    const hi = 800 - 8 - p.widths.right - 8 - p.widths.center
    assert.equal(p.centerX, hi)
    assert.ok(p.centerX + p.widths.center <= 800 - 8 - p.widths.right)
})

ok("hide stage: ascending priority — settings (20) first, workspaces (95) last", () => {
    const p = planFit(Object.assign({ width: 700 }, fixture()))   // compact 716 > 700
    assert.equal(p.stage, "hide")
    assert.deepEqual(p.hidden, ["velocity.settings"])
    assert.deepEqual(p.compacted, ["velocity.clock"])
    assert.equal(p.maps.right["velocity.settings"], "collapsed")
    assert.equal(p.maps.right["velocity.logs"], "full")
    assert.equal(p.fits, true)
})

ok("width sweep 700/1093/1366/1920/3440: never overlaps the rails", () => {
    for (const width of [700, 1093, 1366, 1920, 3440]) {
        const p = planFit(Object.assign({ width, slack: 8 }, fixture()))
        const lo = 8 + p.widths.left + 8
        const hi = width - 8 - p.widths.right - 8 - p.widths.center
        assert.ok(p.centerX >= Math.min(lo, hi), width + " centerX < lo")
        assert.ok(p.centerX <= Math.max(lo, hi), width + " centerX > hi")
        assert.ok(p.centerX + p.widths.center <= width - 8 - p.widths.right + (p.fits ? 0 : 1),
            width + " center overlaps right rail")
        assert.ok(p.centerX >= 8 + (p.fits ? 0 : -1), width + " center overlaps left rail")
    }
})

ok("stage progression across the sweep", () => {
    assert.equal(planFit(Object.assign({ width: 700 }, fixture())).stage, "hide")
    assert.equal(planFit(Object.assign({ width: 720 }, fixture())).stage, "compact")
    assert.equal(planFit(Object.assign({ width: 800 }, fixture())).stage, "compact")
    assert.equal(planFit(Object.assign({ width: 1000 }, fixture())).stage, "full")
    assert.equal(planFit(Object.assign({ width: 1093 }, fixture())).stage, "full")
    assert.equal(planFit(Object.assign({ width: 1366 }, fixture())).stage, "full")
    assert.equal(planFit(Object.assign({ width: 1920 }, fixture())).stage, "full")
    assert.equal(planFit(Object.assign({ width: 3440 }, fixture())).stage, "full")
})

ok("center pulled toward the rails when the ideal would overlap", () => {
    // wide left rail pushes the clamp right of center
    const p = planFit({ width: 1000, pad: 0, gap: 0,
        left: [c("big", 600)], center: [c("m", 200)], right: [c("r", 100)] })
    assert.equal(p.stage, "full")
    assert.equal(p.centerX, 600)            // lo = 600, ideal = 400 → clamped up
    assert.equal(p.centerX + 200, 800)
    assert.equal(p.widths.right, 100)
})

ok("degenerate: ultra-narrow window hides everything (empty bar fits any width)", () => {
    const p = planFit({ width: 50, left: [c("a", 100)], center: [], right: [c("b", 90)] })
    assert.equal(p.stage, "hide")
    assert.deepEqual(p.hidden.sort(), ["a", "b"])
    assert.equal(p.fits, true)
    assert.equal(p.centerX, 25)
})

ok("empty center still reports a sane centerX; gap applied between visible cells only", () => {
    const p = planFit({ width: 1000, pad: 8, gap: 8, left: [c("a", 100)], center: [], right: [c("b", 100, 100, 20)] })
    assert.equal(p.widths.center, 0)
    assert.equal(p.centerX, 500)
    const p2 = planFit({ width: 300, pad: 0, gap: 8, left: [c("a", 100), c("b", 100)], center: [], right: [] })
    assert.equal(p2.widths.left, 208)       // 100+100+one gap
})

console.log("fit.test.mjs: " + n + " assertions passed")
