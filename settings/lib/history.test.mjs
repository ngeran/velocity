// history.test.mjs — ring-buffer append/evict + peak helpers
import { strict as assert } from "node:assert"
import { appendHistory, peakValue } from "./history.mjs"

let n = 0
function ok(name, fn) { fn(); n++; console.log("  ok " + name) }

ok("append adds a sample and never mutates the input array", () => {
    const cur = [{ time: 1000, value: 1 }]
    const next = appendHistory(cur, 2000, 2, 60000, 10)
    assert.equal(next.length, 2)
    assert.deepEqual(next[1], { time: 2000, value: 2 })
    assert.equal(cur.length, 1, "original untouched (identity-stable Repeater bindings)")
})

ok("samples older than windowMs are evicted", () => {
    let h = []
    h = appendHistory(h, 0, 1, 60000, 10)
    h = appendHistory(h, 30000, 2, 60000, 10)
    h = appendHistory(h, 70000, 3, 60000, 10)   // cutoff 10000 drops the t=0 sample
    assert.deepEqual(h.map(s => s.time), [30000, 70000])
})

ok("capped to the newest maxSamples entries", () => {
    let h = []
    for (let t = 0; t < 10; t++) h = appendHistory(h, t * 1000, t, 3600_000, 4)
    assert.deepEqual(h.map(s => s.value), [6, 7, 8, 9])
})

ok("non-finite or negative values return the current array as-is", () => {
    const cur = [{ time: 1000, value: 1 }]
    assert.equal(appendHistory(cur, 2000, NaN, 60000, 10), cur)
    assert.equal(appendHistory(cur, 2000, Infinity, 60000, 10), cur)
    assert.equal(appendHistory(cur, 2000, -1, 60000, 10), cur)
})

ok("peakValue: max of finite samples, junk tolerated", () => {
    assert.equal(peakValue([{ time: 0, value: 3 }, { time: 1, value: 7 }, { time: 2, value: 5 }]), 7)
    assert.equal(peakValue([{ time: 0, value: NaN }, { time: 1, value: "2" }]), 2, "stringy numbers coerced")
    assert.equal(peakValue([{ time: 0, value: "junk" }]), 0)
    assert.equal(peakValue([]), 0)
    assert.equal(peakValue(null), 0)
})

console.log(`history.test.mjs: ${n} ok`)
