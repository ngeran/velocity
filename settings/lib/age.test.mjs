// age.test.mjs — pinned boundaries for ageLabel (fixed clock, no Date.now()).
import { strict as assert } from "node:assert"
import { ageLabel } from "./age.mjs"

let n = 0
const ok = (name, fn) => { fn(); n++; console.log("  ok " + name) }
const NOW = 1750000000000

ok("buckets", () => {
    assert.equal(ageLabel(NOW, NOW), "just now")
    assert.equal(ageLabel(NOW - 59_000, NOW), "just now")
    assert.equal(ageLabel(NOW - 60_000, NOW), "1m ago")
    assert.equal(ageLabel(NOW - 59 * 60_000, NOW), "59m ago")
    assert.equal(ageLabel(NOW - 60 * 60_000, NOW), "1h ago")
    assert.equal(ageLabel(NOW - 23 * 3600_000, NOW), "23h ago")
    assert.equal(ageLabel(NOW - 24 * 3600_000, NOW), "1d ago")
    assert.equal(ageLabel(NOW - 3 * 86400_000, NOW), "3d ago")
})

ok("junk input", () => {
    assert.equal(ageLabel(undefined, NOW), "")
    assert.equal(ageLabel("x", NOW), "")
    assert.equal(ageLabel(-5, NOW), "")
    assert.equal(ageLabel(NOW + 1000, NOW), "")   // future ts — never negative
})

console.log(`age.test: ${n} passed`)
