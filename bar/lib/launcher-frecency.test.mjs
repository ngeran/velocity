// launcher-frecency.test.mjs — decay math, migration, terms and history core.
import { strict as assert } from "node:assert"
import {
    DAY_MS, LAMBDA, TERM_WINDOW_MS, TERM_CAP, HISTORY_CAP,
    scoreOf, bumpAnchor, scoresFromAnchors, emptyState, loadState,
    recordTerm, liveTerms, recordHistory, recordLaunch, toggleId,
} from "./launcher-frecency.mjs"

let n = 0
function ok(name, fn) { fn(); n++; console.log("  ok " + name) }

const NOW = 1730000000000
const EPS = 1e-9

ok("scoreOf: a fresh bump scores exactly the visit bonus", () => {
    const anchor = bumpAnchor(null, NOW)
    assert.ok(Math.abs(scoreOf(anchor, NOW) - 100) < EPS)
})

ok("scoreOf: 10-day half-life (100 → 50 → 25)", () => {
    const anchor = bumpAnchor(null, NOW)
    assert.ok(Math.abs(scoreOf(anchor, NOW + 10 * DAY_MS) - 50) < EPS)
    assert.ok(Math.abs(scoreOf(anchor, NOW + 20 * DAY_MS) - 25) < EPS)
})

ok("scoreOf: past anchors floor at 1, junk anchors score 0", () => {
    assert.equal(scoreOf(NOW - 365 * DAY_MS, NOW), 1)
    assert.equal(scoreOf(undefined, NOW), 0)
    assert.equal(scoreOf("soon", NOW), 0)
    assert.equal(scoreOf(0, NOW), 0)
    assert.equal(scoreOf(-5, NOW), 0)
})

ok("scoreOf: absurd far-future anchor stays finite", () => {
    assert.ok(isFinite(scoreOf(NOW + 1e12 * DAY_MS, NOW)))
})

ok("bumpAnchor: same-instant visits fold additively (100 then 200)", () => {
    const a1 = bumpAnchor(null, NOW)
    const a2 = bumpAnchor(a1, NOW)
    assert.ok(Math.abs(scoreOf(a2, NOW) - 200) < EPS)
})

ok("bumpAnchor: a decade-idle app jumps from the floor to 1 + bonus", () => {
    const idle = NOW - 3650 * DAY_MS
    assert.ok(Math.abs(scoreOf(bumpAnchor(idle, NOW), NOW) - 101) < EPS)
})

ok("scoresFromAnchors: numbers kept, junk dropped", () => {
    const out = scoresFromAnchors({ "a.desktop": bumpAnchor(null, NOW), bad: "x", zero: 0 }, NOW)
    assert.deepEqual(Object.keys(out), ["a.desktop"])
    assert.ok(Math.abs(out["a.desktop"] - 100) < EPS)
})

ok("loadState: clean v2 passes through unchanged", () => {
    const st = emptyState()
    st.frecency["a.desktop"] = NOW
    st.terms["a.desktop"] = [{ t: "ff", at: NOW }]
    st.history.push({ q: "ff", at: NOW })
    const r = loadState(st, NOW)
    assert.equal(r.changed, false)
    assert.deepEqual(r.state, st)
})

ok("loadState: v2 with junk fields is repaired (changed)", () => {
    const r = loadState({
        v: 2,
        frecency: { "a.desktop": NOW, bad: "x" },
        terms: { "a.desktop": [{ t: "ff", at: NOW }, { t: "", at: NOW }, "nope"] },
        history: [{ q: "ff", at: NOW }, { q: 7, at: NOW }],
    }, NOW)
    assert.equal(r.changed, true)
    assert.deepEqual(Object.keys(r.state.frecency), ["a.desktop"])
    assert.deepEqual(r.state.terms["a.desktop"], [{ t: "ff", at: NOW }])
    assert.deepEqual(r.state.history, [{ q: "ff", at: NOW }])
})

ok("loadState: legacy {id: count} migrates preserving today's order", () => {
    const r = loadState({ "calc.desktop": 5, "kitty.desktop": 1, "zero.desktop": 0 }, NOW)
    assert.equal(r.changed, true)
    assert.deepEqual(Object.keys(r.state.frecency).sort(), ["calc.desktop", "kitty.desktop"])
    const s = scoresFromAnchors(r.state.frecency, NOW)
    assert.ok(Math.abs(s["calc.desktop"] - 5) < EPS)
    assert.ok(Math.abs(s["kitty.desktop"] - 1) < EPS)
    assert.equal(s["zero.desktop"], undefined)   // count 0 = never launched
})

ok("loadState: mixed legacy salvages the numeric counts, drops junk", () => {
    const r = loadState({ a: 3, b: "x", c: 1 }, NOW)
    assert.equal(r.changed, true)
    assert.deepEqual(Object.keys(r.state.frecency).sort(), ["a", "c"])
    const s = scoresFromAnchors(r.state.frecency, NOW)
    assert.ok(Math.abs(s.a - 3) < EPS)
    assert.ok(Math.abs(s.c - 1) < EPS)
})

ok("loadState: absent file → empty, nothing to write; garbage → repaired", () => {
    assert.deepEqual(loadState(null, NOW), { state: emptyState(), changed: false })
    assert.equal(loadState("nope", NOW).changed, true)
    assert.equal(loadState([1, 2], NOW).changed, true)
    assert.equal(loadState({ a: "x", b: [] }, NOW).changed, true)   // no numbers at all
})

ok("recordTerm: skips empty, short and oversized terms", () => {
    const st = emptyState()
    assert.equal(recordTerm(st, "a.desktop", "", NOW), st)
    assert.equal(recordTerm(st, "a.desktop", "f", NOW), st)
    assert.equal(recordTerm(st, "", "ff", NOW), st)
    assert.equal(recordTerm(st, "a.desktop", "x".repeat(65), NOW), st)
})

ok("recordTerm: duplicate string re-records fresh instead of piling up", () => {
    let st = emptyState()
    st = recordTerm(st, "a.desktop", "ff", NOW - 5 * DAY_MS)
    st = recordTerm(st, "a.desktop", "ff", NOW)
    assert.deepEqual(st.terms["a.desktop"], [{ t: "ff", at: NOW }])
})

ok("recordTerm: cap keeps the NEWEST terms", () => {
    let st = emptyState()
    for (let i = 0; i < TERM_CAP + 5; i++)
        st = recordTerm(st, "a.desktop", "term" + i, NOW + i)
    const list = st.terms["a.desktop"]
    assert.equal(list.length, TERM_CAP)
    assert.equal(list[0].t, "term5")        // oldest five fell off
    assert.equal(list[list.length - 1].t, "term" + (TERM_CAP + 4))
})

ok("recordTerm: expired terms drop off on the next record", () => {
    let st = emptyState()
    st = recordTerm(st, "a.desktop", "old", NOW - TERM_WINDOW_MS - 1)
    st = recordTerm(st, "a.desktop", "new", NOW)
    assert.deepEqual(st.terms["a.desktop"], [{ t: "new", at: NOW }])
})

ok("liveTerms: only unexpired terms, junk skipped", () => {
    const st = emptyState()
    st.terms["a.desktop"] = [
        { t: "live", at: NOW - 1 },
        { t: "dead", at: NOW - TERM_WINDOW_MS - 1 },
        "junk",
    ]
    st.terms["b.desktop"] = [{ t: "only-dead", at: NOW - TERM_WINDOW_MS - 1 }]
    st.terms["c.desktop"] = "not-a-list"
    assert.deepEqual(liveTerms(st, NOW), { "a.desktop": ["live"] })
})

ok("recordHistory: empty never records, exact repeat moves to the end", () => {
    let st = emptyState()
    st = recordHistory(st, "  ", NOW)
    assert.deepEqual(st.history, [])
    st = recordHistory(st, "ff", NOW - 1000)
    st = recordHistory(st, "gg", NOW - 500)
    st = recordHistory(st, "ff", NOW)
    assert.deepEqual(st.history.map(h => h.q), ["gg", "ff"])
})

ok("recordHistory: cap keeps the latest queries", () => {
    let st = emptyState()
    for (let i = 0; i < HISTORY_CAP + 3; i++)
        st = recordHistory(st, "q" + i, NOW + i)
    assert.equal(st.history.length, HISTORY_CAP)
    assert.equal(st.history[0].q, "q3")
    assert.equal(st.history[st.history.length - 1].q, "q" + (HISTORY_CAP + 2))
})

ok("recordLaunch: with id → frecency + term + history", () => {
    const st = recordLaunch(emptyState(), "ff.desktop", "ff", NOW)
    assert.ok(Math.abs(scoreOf(st.frecency["ff.desktop"], NOW) - 100) < EPS)
    assert.deepEqual(st.terms["ff.desktop"], [{ t: "ff", at: NOW }])
    assert.deepEqual(st.history, [{ q: "ff", at: NOW }])
})

ok("recordLaunch: null id → history only (calc/shell/web launches)", () => {
    const st = recordLaunch(emptyState(), null, "=2+2", NOW)
    assert.deepEqual(st.frecency, {})
    assert.deepEqual(st.terms, {})
    assert.deepEqual(st.history, [{ q: "=2+2", at: NOW }])
})

ok("recordLaunch: empty-string id is history-only too", () => {
    const st = recordLaunch(emptyState(), "", "ff", NOW)
    assert.deepEqual(st.frecency, {})
    assert.deepEqual(st.terms, {})
    assert.deepEqual(st.history, [{ q: "ff", at: NOW }])
})

ok("learned terms are lowercased: launch from \"FF\" → alias matches \"ff\"", () => {
    const st = recordLaunch(emptyState(), "ff.desktop", "FF", NOW)
    assert.deepEqual(st.terms["ff.desktop"], [{ t: "ff", at: NOW }])
    assert.deepEqual(liveTerms(st, NOW), { "ff.desktop": ["ff"] })
})

ok("recordLaunch: short query still bumps frecency, learns nothing", () => {
    const st = recordLaunch(emptyState(), "ff.desktop", "f", NOW)
    assert.ok(Math.abs(scoreOf(st.frecency["ff.desktop"], NOW) - 100) < EPS)
    assert.deepEqual(st.terms, {})
})

ok("loadState: v2 favorites/hidden backfilled, junk repaired, dupes collapsed", () => {
    const r = loadState({ v: 2, favorites: ["a.desktop", "a.desktop", 7, ""],
                          hidden: "nope" }, NOW)
    assert.equal(r.changed, true)
    assert.deepEqual(r.state.favorites, ["a.desktop"])
    assert.deepEqual(r.state.hidden, [])
})

ok("loadState: clean v2 favorites/hidden pass through, absent = empty, no rewrite", () => {
    const st = emptyState()
    st.favorites = ["a.desktop", "b.desktop"]
    const r = loadState(st, NOW)
    assert.equal(r.changed, false)
    assert.deepEqual(r.state.favorites, ["a.desktop", "b.desktop"])
    const absent = loadState({ v: 2 }, NOW)
    assert.equal(absent.changed, false)
    assert.deepEqual(absent.state.favorites, [])
    assert.deepEqual(absent.state.hidden, [])
    const explicit = loadState({ v: 2, favorites: [], hidden: [] }, NOW)
    assert.equal(explicit.changed, false)
})

ok("toggleId: absent → appended, present → removed, order preserved", () => {
    assert.deepEqual(toggleId(["a", "b"], "c"), ["a", "b", "c"])
    assert.deepEqual(toggleId(["a", "b", "c"], "b"), ["a", "c"])
    assert.deepEqual(toggleId(null, "x"), ["x"])
    assert.deepEqual(toggleId(["a"], "a"), [])
})

ok("recordLaunch leaves favorites/hidden untouched", () => {
    const st0 = emptyState()
    st0.favorites = ["a.desktop"]
    st0.hidden = ["b.desktop"]
    const st = recordLaunch(st0, "c.desktop", "cc", NOW)
    assert.deepEqual(st.favorites, ["a.desktop"])
    assert.deepEqual(st.hidden, ["b.desktop"])
})

console.log("launcher-frecency: " + n + " assertions passed")
