// battery-events.test.mjs — battery edge detection (J7)
import * as Be from "./battery-events.mjs"

let n = 0
function ok(cond, label) {
    n++
    if (!cond) { console.error("FAIL: " + label); process.exitCode = 1 }
}
function eqv(got, want, label) {
    n++
    if (JSON.stringify(got) !== JSON.stringify(want)) {
        console.error("FAIL: " + label + "\n  got:  " + JSON.stringify(got) +
                      "\n  want: " + JSON.stringify(want))
        process.exitCode = 1
    }
}
const kinds = (r) => r.events.map((e) => e.kind)
const opts = { lowThreshold: 20, debounceMs: 2000 }

// ── baseline: boot fires nothing ────────────────────────────────────────────
let r = Be.update(Be.initState(), { has: true, charging: true, full: false, pct: 42 }, opts, 1000)
eqv(kinds(r), [], "boot while charging: silent (baseline)")
ok(r.state.seen === true && r.state.charging === true && r.state.pct === 42,
   "baseline records charging + pct")
ok(r.state.lowArmed === true, "boot at 42 > 20 arms low")

r = Be.update(Be.initState(), { has: true, charging: false, full: false, pct: 15 }, opts, 1000)
ok(r.state.lowArmed === false, "boot below threshold does NOT arm (restart-quiet)")

// ── plug ────────────────────────────────────────────────────────────────────
let st = Be.update(Be.initState(), { has: true, charging: false, full: false, pct: 55 }, opts, 0).state
r = Be.update(st, { has: true, charging: true, full: false, pct: 55 }, opts, 5000)
eqv(kinds(r), ["plug"], "charging false→true fires plug")
ok(r.state.lowArmed === true, "plug re-arms low")

// unplug is deliberately not an event
st = r.state
r = Be.update(st, { has: true, charging: false, full: false, pct: 57 }, opts, 9000)
eqv(kinds(r), [], "unplug fires nothing (spec lists three)")
ok(r.state.lowArmed === true, "still armed after unplug above threshold")

// ── full ────────────────────────────────────────────────────────────────────
st = Be.update(Be.initState(), { has: true, charging: true, full: false, pct: 96 }, opts, 0).state
r = Be.update(st, { has: true, charging: false, full: true, pct: 100 }, opts, 60000)
eqv(kinds(r), ["full"], "state→FullyCharged fires full")
ok(r.state.lowArmed === true, "full re-arms low")

// full reported while still charging-flagged (some cells) still fires
st = Be.update(Be.initState(), { has: true, charging: true, full: false, pct: 99 }, opts, 0).state
r = Be.update(st, { has: true, charging: true, full: true, pct: 99 }, opts, 60000)
eqv(kinds(r), ["full"], "full fires with real pct when reported early")

// full WITHIN the debounce window of an accepted plug still fires (the full
// edge bypasses the debounce — only charging flaps are gated)
st = Be.update(Be.initState(), { has: true, charging: false, full: false, pct: 97 }, opts, 0).state
r = Be.update(st, { has: true, charging: true, full: false, pct: 98 }, opts, 1000)
eqv(kinds(r), ["plug"], "plug accepted (baseline seeds -Infinity)")
r = Be.update(r.state, { has: true, charging: true, full: true, pct: 100 }, opts, 2500)
eqv(kinds(r), ["full"], "full fires 1.5 s after the plug, inside the 2 s window")
eqv(kinds(Be.update(r.state, { has: true, charging: true, full: true, pct: 100 }, opts, 60000)), [], "no duplicate full on the next still-full sample")

// charging flap stays debounced (regression: the exemption is full-only) —
// an accepted plug first (baseline seeds -Infinity, so the FIRST plug is
// always real), then the unplug flap inside 2 s is swallowed
st = Be.update(Be.initState(), { has: true, charging: false, full: false, pct: 55 }, opts, 0).state
r = Be.update(st, { has: true, charging: true, full: false, pct: 55 }, opts, 10000)
eqv(kinds(r), ["plug"], "plug outside the window accepted")
r = Be.update(r.state, { has: true, charging: false, full: false, pct: 55 }, opts, 11000)
eqv(kinds(r), [], "charging edge inside the window is swallowed")

// ── low ─────────────────────────────────────────────────────────────────────
// Threshold semantics are ≤ (the pill's error colour uses the same <= in
// BarWidget): AT the threshold is already "low".
st = Be.update(Be.initState(), { has: true, charging: false, full: false, pct: 30 }, opts, 0).state
r = Be.update(st, { has: true, charging: false, full: false, pct: 20 }, opts, 120000)
eqv(kinds(r), ["low"], "pct == threshold fires (≤ semantics, matches pill error)")
ok(r.state.lowArmed === false, "low disarms itself")
r = Be.update(r.state, { has: true, charging: false, full: false, pct: 19 }, opts, 180000)
eqv(kinds(r), [], "no re-fire while ≤ threshold (one nag per drain)")

// charging suppresses low even below threshold (plugged in is not "low")
st = Be.update(Be.initState(), { has: true, charging: true, full: false, pct: 12 }, opts, 0).state
r = Be.update(st, { has: true, charging: true, full: false, pct: 10 }, opts, 120000)
eqv(kinds(r), [], "low never fires while charging")

// low while FullyCharged-flagged: suppressed (state wins over threshold)
st = Be.update(Be.initState(), { has: true, charging: false, full: true, pct: 18 }, opts, 0).state
r = Be.update(st, { has: true, charging: false, full: true, pct: 17 }, opts, 120000)
eqv(kinds(r), [], "low never fires while fully-charged flag set")

// re-arm on climb back above threshold
st = Be.update(Be.initState(), { has: true, charging: false, full: false, pct: 30 }, opts, 0).state
r = Be.update(st, { has: true, charging: false, full: false, pct: 18 }, opts, 60000)
eqv(kinds(r), ["low"], "armed discharge crosses → low")
r = Be.update(r.state, { has: true, charging: true, full: false, pct: 18 }, opts, 120000)
eqv(kinds(r), ["plug"], "plugging in while low fires plug")
st = r.state
ok(st.lowArmed === true, "plug re-arms low")
r = Be.update(st, { has: true, charging: false, full: false, pct: 60 }, opts, 180000)
eqv(kinds(r), [], "recharge climb fires nothing (full event needs the flag)")
ok(r.state.lowArmed === true, "climb above threshold keeps low armed")
r = Be.update(r.state, { has: true, charging: false, full: false, pct: 19 }, opts, 300000)
eqv(kinds(r), ["low"], "second drain after a full recharge fires again")

// ── debounce: AC flap swallowed, percentage exempt ──────────────────────────
st = Be.update(Be.initState(), { has: true, charging: false, full: false, pct: 55 }, opts, 0).state
r = Be.update(st, { has: true, charging: true, full: false, pct: 55 }, opts, 1000)
eqv(kinds(r), ["plug"], "first transition accepted")
st = r.state
r = Be.update(st, { has: true, charging: false, full: false, pct: 55 }, opts, 1500)
eqv(kinds(r), [], "opposite flip 500 ms later: debounced (no unplug anyway)")
ok(r.state.charging === true, "debounced sample leaves charging state intact")
r = Be.update(r.state, { has: true, charging: false, full: false, pct: 54 }, opts, 1800)
eqv(kinds(r), [], "flip again < 2 s: still debounced")
r = Be.update(r.state, { has: true, charging: false, full: false, pct: 54 }, opts, 3200)
eqv(kinds(r), [], "flip 2.2 s after the accepted one: real unplug, not an event")
ok(r.state.charging === false, "accepted transition lands")
r = Be.update(r.state, { has: true, charging: false, full: false, pct: 19 }, opts, 3000)
eqv(kinds(r), ["low"], "percentage bypasses the debounce — crossing fires immediately")

// debounce window is measured from the last ACCEPTED transition
st = Be.update(Be.initState(), { has: true, charging: false, full: false, pct: 55 }, opts, 0).state
st = Be.update(st, { has: true, charging: true, full: false, pct: 55 }, opts, 10000).state
r = Be.update(st, { has: true, charging: false, full: false, pct: 55 }, opts, 20000)
eqv(kinds(r), [], "accepted unplug (10 s gap), no event by design")
r = Be.update(r.state, { has: true, charging: true, full: false, pct: 55 }, opts, 25000)
eqv(kinds(r), ["plug"], "flap 5 s after the accepted one gets through")

// ── no battery: permanently silent ──────────────────────────────────────────
r = Be.update(Be.initState(), { has: false, charging: false, full: false, pct: 0 }, opts, 0)
eqv(kinds(r), [], "no battery: silent")
ok(r.state.seen === false, "no battery: never baselined")
st = Be.update(Be.initState(), { has: true, charging: false, full: false, pct: 50 }, opts, 0).state
r = Be.update(st, { has: false, charging: true, full: false, pct: 50 }, opts, 60000)
eqv(kinds(r), [], "battery disappearing mid-session: silent")
ok(r.state.seen === true, "battery disappearing: state frozen, not reset")

// ── degenerate inputs ───────────────────────────────────────────────────────
r = Be.update(Be.initState(), { has: true, charging: false, full: false, pct: "junk" }, opts, 0)
ok(r.state.pct === 100, "non-numeric pct → 100 (no NaN into the label)")
r = Be.update(Be.initState(), { has: true, charging: false, full: false, pct: 140 }, opts, 0)
ok(r.state.pct === 100, "pct clamped high")
r = Be.update(Be.initState(), { has: true, charging: false, full: false, pct: -3 }, opts, 0)
ok(r.state.pct === 0, "pct clamped low")
r = Be.update(null, { has: true, charging: true, full: false, pct: 50 }, opts, 0)
eqv(kinds(r), [], "null state baselines safely")

console.log("battery-events: " + n + " asserts OK")
