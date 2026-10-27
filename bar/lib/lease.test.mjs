// lease.test.mjs — pinned boundaries for the H7 polling lease.
import { strict as assert } from "node:assert"
import { LEASE_MAX_S, acquire, expired, remainingMs } from "./lease.mjs"

let n = 0
const ok = (name, fn) => { fn(); n++; console.log("  ok " + name) }
const NOW = 1750000000000

ok("acquire clamps to LEASE_MAX_S", () => {
    assert.equal(acquire(60, NOW), NOW + LEASE_MAX_S * 1000)
    assert.equal(acquire(30, NOW), NOW + 30 * 1000)
    assert.equal(acquire(10, NOW), NOW + 10 * 1000)
})

ok("acquire rejects junk / non-positive", () => {
    assert.equal(acquire(0, NOW), 0)
    assert.equal(acquire(-5, NOW), 0)
    assert.equal(acquire(NaN, NOW), 0)
    assert.equal(acquire("10", NOW), 0)
    assert.equal(acquire(undefined, NOW), 0)
})

ok("acquire floors fractional seconds", () => {
    assert.equal(acquire(10.9, NOW), NOW + 10 * 1000)
})

ok("expired boundary: == is gone", () => {
    assert.equal(expired(NOW + 1000, NOW), false)
    assert.equal(expired(NOW + 1000, NOW + 1000), true)
    assert.equal(expired(NOW + 1000, NOW + 1001), true)
})

ok("expired treats junk / zero as gone", () => {
    assert.equal(expired(0, NOW), true)
    assert.equal(expired(undefined, NOW), true)
    assert.equal(expired(NaN, NOW), true)
})

ok("remainingMs floors at 0", () => {
    assert.equal(remainingMs(NOW + 5000, NOW), 5000)
    assert.equal(remainingMs(NOW + 5000, NOW + 9000), 0)
    assert.equal(remainingMs(0, NOW), 0)
})

console.log(`lease.test: ${n} passed`)
