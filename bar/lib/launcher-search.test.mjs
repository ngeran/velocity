// launcher-search.test.mjs — the launcher's rank/highlight/selection core.
import { strict as assert } from "node:assert"
import { rank, highlight, segments, resultKey, reconcileSelection, route, windowEntries } from "./launcher-search.mjs"

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

console.log("launcher-search: " + n + " assertions passed")
