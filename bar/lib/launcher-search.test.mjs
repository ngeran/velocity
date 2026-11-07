// launcher-search.test.mjs — the launcher's rank/highlight/selection core.
import { strict as assert } from "node:assert"
import { rank, highlight, segments, resultKey, reconcileSelection, route, windowEntries, filterHidden, groupedEmptyView, hiddenRows } from "./launcher-search.mjs"

let n = 0
function ok(name, fn) { fn(); n++; console.log("  ok " + name) }

const APPS = [
    { id: "chromium.desktop", name: "Chromium", genericName: "Web Browser", keywords: ["internet"] },
    { id: "kitty.desktop", name: "kitty", genericName: "Terminal", keywords: ["shell", "console"] },
    { id: "files.desktop", name: "Files", genericName: "File Manager", keywords: ["nautilus", "disk"] },
    { id: "calc.desktop", name: "Calculator", genericName: "", keywords: ["math", "bc"] },
    { id: "hidden.desktop", name: "HiddenApp", noDisplay: true },
]

ok("noDisplay entries never rank", () => {
    const out = rank(APPS, "hidden", {})
    assert.equal(out.length, 0)
})

ok("empty query: usage order desc, then name", () => {
    const out = rank(APPS, "", { "calc.desktop": 5, "kitty.desktop": 2 })
    assert.equal(out[0].id, "calc.desktop")
    assert.equal(out[1].id, "kitty.desktop")
    assert.equal(out[out.length - 1].id, "files.desktop") // 0-use names alphabetical
})

ok("empty query with no usage: plain name sort", () => {
    const out = rank(APPS, "", {})
    assert.deepEqual(out.map(e => e.id), ["calc.desktop", "chromium.desktop", "files.desktop", "kitty.desktop"])
})

ok("prefix beats substring beats subsequence", () => {
    const pool = [
        { id: "subseq.desktop", name: "unit test" },   // n-e-t spread out (tier 2)
        { id: "substr.desktop", name: "Ethernet" },    // "net" inside (tier 1)
        { id: "prefix.desktop", name: "Network" },     // starts with it (tier 0)
    ]
    const out = rank(pool, "net", {})
    assert.equal(out[0].id, "prefix.desktop")
    assert.equal(out[1].id, "substr.desktop")
    assert.equal(out[2].id, "subseq.desktop")
})

ok("no match: entry drops out", () => {
    assert.equal(rank(APPS, "zzzz", {}).length, 0)
})

ok("keywords and genericName match at substring tier", () => {
    const out = rank(APPS, "console", {})
    assert.equal(out[0].id, "kitty.desktop")
    const out2 = rank(APPS, "manager", {})
    assert.equal(out2[0].id, "files.desktop")
})

ok("equal tier: usage breaks the tie", () => {
    const pool = [
        { id: "a.desktop", name: "Alpha Term" },
        { id: "b.desktop", name: "Beta Term" },
    ]
    const out = rank(pool, "term", { "b.desktop": 3 })
    assert.equal(out[0].id, "b.desktop")
})

ok("learned term: exact match is an alias above a name prefix", () => {
    const pool = [
        { id: "files.desktop", name: "Files" },      // "fi" prefix (tier 0)
        { id: "ff.desktop", name: "Firefox" },       // "fi" subsequence (tier 2)
    ]
    const out = rank(pool, "fi", {}, { "ff.desktop": ["fi"] })
    assert.equal(out[0].id, "ff.desktop")            // term −1 beats both
})

ok("learned term: query prefixing a term joins tier 0, usage breaks the tie", () => {
    const pool = [
        { id: "files.desktop", name: "Files" },
        { id: "ff.desktop", name: "Firefox" },
    ]
    const plain = rank(pool, "fi", {})
    assert.equal(plain[0].id, "files.desktop")       // no terms: prefix wins
    const learned = rank(pool, "fi", { "ff.desktop": 50 }, { "ff.desktop": ["fin"] })
    assert.equal(learned[0].id, "ff.desktop")        // term-prefix tier 0 + usage
})

ok("learned terms never leak to other ids", () => {
    const pool = [
        { id: "v.desktop", name: "FFview" },         // "ff" name prefix
        { id: "ff.desktop", name: "Firefox" },       // "ff" subsequence
    ]
    const out = rank(pool, "ff", {}, { "unrelated.desktop": ["ff"] })
    assert.equal(out[0].id, "v.desktop")
})

ok("empty query ignores terms (usage order unchanged)", () => {
    const out = rank(APPS, "", { "kitty.desktop": 9 }, { "calc.desktop": ["zz"] })
    assert.equal(out[0].id, "kitty.desktop")
})

ok("highlight: subsequence spans, merged runs", () => {
    assert.deepEqual(highlight("NetworkManager", "net"), [{ start: 0, len: 3 }])
    assert.deepEqual(highlight("Netflix", "ntx"), [{ start: 0, len: 1 }, { start: 2, len: 1 }, { start: 6, len: 1 }])
    assert.deepEqual(highlight("abcabc", "abc"), [{ start: 0, len: 3 }])
})

ok("highlight: no full subsequence or empty query → no spans", () => {
    assert.deepEqual(highlight("NetworkManager", "xyz"), [])
    assert.deepEqual(highlight("Anything", ""), [])
})

ok("segments: cut along spans, hit flags true only inside", () => {
    assert.deepEqual(segments("NetworkManager", [{ start: 0, len: 3 }]), [
        { text: "Net", hit: true },
        { text: "workManager", hit: false },
    ])
    assert.deepEqual(segments("Netflix", [{ start: 0, len: 1 }, { start: 2, len: 1 }, { start: 6, len: 1 }]), [
        { text: "N", hit: true }, { text: "e", hit: false },
        { text: "t", hit: true }, { text: "fli", hit: false },
        { text: "x", hit: true },
    ])
    assert.deepEqual(segments("", []), [])
})

ok("resultKey: provider-scoped string identity", () => {
    assert.equal(resultKey("apps", "kitty.desktop"), '["apps","kitty.desktop"]')
    assert.notEqual(resultKey("apps", "kitty.desktop"), resultKey("windows", "kitty.desktop"))
})

ok("reconcile: selection follows its row to the new index", () => {
    const rows = [{ resultKey: '["apps","a"]' }, { resultKey: '["apps","b"]' }, { resultKey: '["apps","c"]' }]
    assert.deepEqual(reconcileSelection(rows, '["apps","c"]', 0), { key: '["apps","c"]', index: 2 })
})

ok("reconcile: row gone → hold the previous index, clamped", () => {
    const rows = [{ resultKey: '["apps","x"]' }, { resultKey: '["apps","y"]' }]
    assert.deepEqual(reconcileSelection(rows, '["apps","gone"]', 4), { key: '["apps","y"]', index: 1 })
    assert.deepEqual(reconcileSelection(rows, '["apps","gone"]', 1), { key: '["apps","y"]', index: 1 })
})

ok("reconcile: empty list clears the selection", () => {
    assert.deepEqual(reconcileSelection([], '["apps","a"]', 0), { key: "", index: -1 })
})

ok("query trim + case insensitivity end to end", () => {
    const out = rank(APPS, "  CHROM ", {})
    assert.equal(out[0].id, "chromium.desktop")
})

ok("route: bare query = apps provider, arg verbatim", () => {
    assert.deepEqual(route("chrom"), { provider: "apps", arg: "chrom" })
    assert.deepEqual(route(""), { provider: "apps", arg: "" })
})

ok("route: = > ? prefixes strip the sigil (shell/web trim)", () => {
    assert.deepEqual(route("=2+2"), { provider: "calc", arg: "2+2" })
    assert.deepEqual(route("> kitty -ls"), { provider: "shell", arg: "kitty -ls" })
    assert.deepEqual(route("? nix flake"), { provider: "web", arg: "nix flake" })
})

ok("windowEntries: hyprctl clients rows → search entries", () => {
    const json = JSON.stringify([
        { address: "0xabc", title: "nvim init.lua", class: "kitty", workspace: { id: 2 } },
        { address: "0xdef", title: "", class: "chromium" },
        { address: "", title: "no address", class: "x" },
    ])
    const out = windowEntries(json)
    assert.equal(out.length, 2)
    assert.deepEqual(out[0], { id: "0xabc", name: "nvim init.lua", genericName: "kitty" })
    assert.equal(out[1].name, "chromium")   // class fallback when the title is empty
})

ok("windowEntries: malformed input → empty (apps-only launcher)", () => {
    assert.deepEqual(windowEntries("not json"), [])
    assert.deepEqual(windowEntries('{"a":1}'), [])
    assert.deepEqual(windowEntries(""), [])
})

// P7 TEST bar: a keystroke over 1000 entries must stay under 50 ms. The
// benchmark runs the worst realistic case — a subsequence query that walks
// every field of every entry, then a sort over the matches.
{
    const big = []
    for (let i = 0; i < 1000; i++)
        big.push({ id: "app" + i, name: "Application " + i, genericName: "Category " + (i % 20), keywords: ["kw" + (i % 50), "tag" + i] })
    const t0 = process.hrtime.bigint()
    let hits = 0
    for (const q of ["app", "application", "app999", "kw7tag3", "zzzznope", "cation 4", "tag99"])
        hits += rank(big, q, { app3: 5 }).length
    const ms = Number(process.hrtime.bigint() - t0) / 1e6
    assert.ok(hits > 0, "benchmark queries matched nothing")
    assert.ok(ms < 50, "rank over 1000 entries x 7 queries took " + ms.toFixed(1) + " ms (budget 50)")
    ok("benchmark: 7 keystrokes over 1000 entries in " + ms.toFixed(1) + " ms (< 50)", () => {})
}

// ── Tier 2: filterHidden / groupedEmptyView / hiddenRows ────────────────────
const VIEW_APPS = [
    { id: "a.desktop", name: "Alpha" },
    { id: "b.desktop", name: "Bravo" },
    { id: "c.desktop", name: "Charlie" },
    { id: "d.desktop", name: "Delta" },
    { id: "e.desktop", name: "Echo" },
    { id: "nope.desktop", name: "Ghost", noDisplay: true },
]

ok("filterHidden: hidden and noDisplay ids drop out", () => {
    const out = filterHidden(VIEW_APPS, ["b.desktop", "zz-gone.desktop"])
    assert.deepEqual(out.map(e => e.id), ["a.desktop", "c.desktop", "d.desktop", "e.desktop"])
})

ok("groupedEmptyView: FAVORITES → SUGGESTIONS → APPLICATIONS with head-only sections", () => {
    const usage = { "a.desktop": 5, "c.desktop": 3, "d.desktop": 1, "e.desktop": 9 }
    const out = groupedEmptyView(VIEW_APPS, usage, ["c.desktop"], [], 2)
    assert.deepEqual(out.map(m => [m.entry.id, m.section || ""]), [
        ["c.desktop", "FAVORITES"],
        ["e.desktop", "SUGGESTIONS"],
        ["a.desktop", ""],
        ["d.desktop", "APPLICATIONS"],
        ["b.desktop", ""],
    ])
})

ok("groupedEmptyView: suggestions = launched, non-favorite, capped; unlaunched land in APPLICATIONS", () => {
    const usage = { "a.desktop": 5, "c.desktop": 3 }
    const out = groupedEmptyView(VIEW_APPS, usage, ["a.desktop"], [], 6)
    assert.deepEqual(out.map(m => [m.entry.id, m.section || ""]), [
        ["a.desktop", "FAVORITES"],
        ["c.desktop", "SUGGESTIONS"],
        ["b.desktop", "APPLICATIONS"],
        ["d.desktop", ""],
        ["e.desktop", ""],
    ])
})

ok("groupedEmptyView: hidden masked everywhere (even favorites); stale pins drop silently", () => {
    const usage = { "c.desktop": 3 }
    const out = groupedEmptyView(VIEW_APPS, usage, ["b.desktop", "c.desktop", "uninstalled.desktop"], ["b.desktop"], 6)
    assert.deepEqual(out.map(m => [m.entry.id, m.section || ""]), [
        ["c.desktop", "FAVORITES"],
        ["a.desktop", "APPLICATIONS"],
        ["d.desktop", ""],
        ["e.desktop", ""],
    ])
})

ok("groupedEmptyView: no favorites, no launches → one APPLICATIONS head only", () => {
    const out = groupedEmptyView(VIEW_APPS, {}, [], [], 6)
    assert.equal(out.filter(m => m.section).length, 1)
    assert.equal(out[0].section, "APPLICATIONS")
})

ok("hiddenRows: only hidden ids, usage-desc, one HIDDEN head", () => {
    const out = hiddenRows(VIEW_APPS, ["b.desktop", "d.desktop", "not-here"], { "b.desktop": 2, "d.desktop": 8 })
    assert.deepEqual(out.map(m => [m.entry.id, m.section || ""]), [
        ["d.desktop", "HIDDEN"],
        ["b.desktop", ""],
    ])
})

ok("hiddenRows: a noDisplay hidden id stays out (it can never be shown)", () => {
    const out = hiddenRows(VIEW_APPS, ["nope.desktop", "b.desktop"], {})
    assert.deepEqual(out.map(m => m.entry.id), ["b.desktop"])
})

ok("groupedEmptyView: empty index → no rows, no section markers", () => {
    assert.deepEqual(groupedEmptyView([], { "a.desktop": 3 }, ["a.desktop"], [], 6), [])
})

ok("groupedEmptyView: suggestLimit 0 (or absent) falls back to 6", () => {
    const usage = {}
    for (const id of ["a", "b", "c", "d", "e", "f", "g", "h"]) usage[id + ".desktop"] = 1
    const apps = Object.keys(usage).map(id => ({ id, name: id }))
    const out0 = groupedEmptyView(apps, usage, [], [], 0)
    const outU = groupedEmptyView(apps, usage, [], [])
    const i0 = out0.findIndex(m => m.section === "SUGGESTIONS")
    const i1 = out0.findIndex(m => m.section === "APPLICATIONS")
    assert.equal(i1 - i0, 6)          // 6 suggestion rows before the tail head
    assert.deepEqual(out0, outU)
})

console.log("launcher-search: " + n + " assertions passed")
