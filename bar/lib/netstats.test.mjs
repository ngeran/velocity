// netstats.test.mjs — regressions for the latency-leg fold + WAN refusal
import test from "node:test"
import assert from "node:assert/strict"
import { fold, wanPoint, WAN_INVERSION_TOLERANCE_MS } from "./netstats.mjs"

const s = (rtt) => ({ ok: rtt !== null, rtt })

test("fold: percentiles, IPDV jitter, loss over a known series", () => {
    // 20 samples, one lost; rtts alternate 10/40 (IPDV must flag it)
    const rtts = [10, 40, 10, 40, 10, 40, 10, 40, 10, 40, 10, 40, 10, 40, 10, 40, 10, 40, 10, 40]
    const samples = rtts.map(s)
    samples[3] = { ok: false, rtt: null }          // replace one 40 with a loss
    const f = fold(samples)
    assert.equal(f.n, 20)
    assert.equal(f.ok, 19)
    assert.equal(f.lost, 1)
    assert.equal(f.lossPct, 5)
    // sorted ok rtts: nineteen 10/40 mix; p50/p75/p95 nearest-rank
    assert.equal(f.p75, 40)
    assert.equal(f.p95, 40)
    // IPDV over consecutive ok rtts: mostly |40-10| = 30, one 10->40 gap bridged
    assert.ok(f.jitter > 0 && f.jitter < 40, "jitter in range, got " + f.jitter)
    // felt = p75 + 1.5*jitter + 0.05 * 5 * max(200, 3*40=120 -> 200)
    const jitterTerm = 1.5 * f.jitter
    const expected = 40 + jitterTerm + 0.05 * 5 * 200
    assert.equal(f.felt, Math.round((expected) * 10) / 10)
})

test("fold: band is monotonic even on inverted samples", () => {
    // craft: p50 > p75 is impossible on sorted data, but the clamp guards
    // hand-built bands — assert through the fold on a skewed series
    const f = fold([s(5), s(5), s(5), s(900), s(950)])
    assert.ok(f.band[0] <= f.band[1] && f.band[1] <= f.band[2],
        "band monotonic: " + JSON.stringify(f.band))
    assert.equal(f.band[2], 950)
})

test("fold: single sample and all-lost edges", () => {
    const one = fold([s(12)])
    assert.equal(one.p50, 12)
    assert.equal(one.p75, 12)
    assert.equal(one.jitter, 0)
    assert.equal(one.lossPct, 0)
    const dead = fold([s(null), s(null)])
    assert.equal(dead.ok, 0)
    assert.equal(dead.lossPct, 100)
    assert.equal(dead.p50, null)
    assert.equal(dead.felt, null)
    assert.equal(fold([]), null)
})

test("wanPoint: normal split, floor at zero, refusal on inversion", () => {
    assert.equal(wanPoint(20, 8), 12)                       // normal split
    assert.equal(wanPoint(5, 8), 0)                         // clamps at zero within tolerance
    assert.equal(wanPoint(30, 100), null)                   // gateway slower than internet: refusal
    assert.equal(wanPoint(20, 20 + WAN_INVERSION_TOLERANCE_MS), 0)  // exactly at tolerance
    assert.equal(wanPoint(20, 20 + WAN_INVERSION_TOLERANCE_MS + 0.5), null)
    assert.equal(wanPoint(NaN, 5), null)
})
