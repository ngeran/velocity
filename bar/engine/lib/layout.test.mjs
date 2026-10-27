// layout.test.mjs — layout normalize/place/move/resolve + schema-1 migration.
import { strict as assert } from "node:assert"
import { readFileSync, readdirSync, existsSync } from "node:fs"
import { join, dirname } from "node:path"
import { fileURLToPath } from "node:url"
import { normalize, place, remove, move, prune, sectionOf, ensurePlaced, resolve, migrate, BUILTIN_IDS, pruneGrace, diffIdLists, PRUNE_GRACE } from "./layout.mjs"
import { parseManifest } from "./manifest.mjs"

let n = 0
function ok(name, fn) { fn(); n++; console.log("  ok " + name) }

const W = (id, extra) => Object.assign({ id, kinds: ["bar-widget"], defaultSection: "right", enabled: true, status: "ready" }, extra || {})

ok("normalize: junk dropped, first occurrence wins across sections", () => {
    assert.deepEqual(normalize(null), { left: [], center: [], right: [] })
    assert.deepEqual(normalize({ left: ["a", 3, "", "a"], center: ["a", "b"], right: "x" }), { left: ["a"], center: ["b"], right: [] })
})

ok("place / remove / move / sectionOf", () => {
    let l = { left: ["a"], center: [], right: ["b", "c"] }
    l = place(l, "a", "right", 1)
    assert.deepEqual(l, { left: [], center: [], right: ["b", "a", "c"] })
    assert.deepEqual(place(l, "z", "center", 99).center, ["z"])
    assert.deepEqual(place(l, "z", "right", -1).right, ["b", "a", "c", "z"])
    assert.throws(() => place(l, "a", "top", 0), /section/)
    assert.deepEqual(move(l, "a", -5).right, ["a", "b", "c"])
    assert.deepEqual(move(l, "a", 1).right, ["b", "c", "a"])
    assert.deepEqual(move(l, "nope", 1), l)
    assert.equal(sectionOf(l, "c"), "right")
    assert.equal(sectionOf(l, "q"), "")
    assert.deepEqual(remove(l, "a").right, ["b", "c"])
    assert.deepEqual(prune(l, ["c"]), { left: [], center: [], right: ["c"] })
})

ok("ensurePlaced appends to defaultSection only when absent", () => {
    const l = { left: [], center: ["x"], right: [] }
    assert.deepEqual(ensurePlaced(l, W("y", { defaultSection: "left" })).left, ["y"])
    assert.deepEqual(ensurePlaced(l, W("x")), l)
    assert.deepEqual(ensurePlaced(l, { id: "svc", kinds: ["service"] }), l)
})

ok("resolve: layout order, hidden when disabled/not ready, unplaced appended", () => {
    const ps = [W("a"), W("b", { enabled: false, status: "disabled" }), W("c", { status: "error" }),
                W("d", { defaultSection: "center" }), W("e"), { id: "s", kinds: ["service"], enabled: true, status: "ready" }]
    const r = resolve({ left: ["e"], center: [], right: ["b", "a", "c", "gone"] }, ps)
    assert.deepEqual(r.left.map(p => p.id), ["e"])
    assert.deepEqual(r.center.map(p => p.id), ["d"])
    assert.deepEqual(r.right.map(p => p.id), ["a"])
})

// The live files are the fixture: the migrated layout must render exactly
// what the schema-1 bar showed.
const root = join(dirname(fileURLToPath(import.meta.url)), "../../..")
function repoPlugins() {
    const out = []
    for (const d of readdirSync(join(root, "plugins")).sort()) {
        const f = join(root, "plugins", d, "manifest.json")
        if (!existsSync(f)) continue
        const r = parseManifest(readFileSync(f, "utf8"), { hostApi: 2 })
        if (r.ok) out.push(Object.assign(r.plugin, { status: "ready", enabled: true }))
    }
    return out
}

ok("migrate: legacy rightLayout + order → schema-2 layout", () => {
    const ps = repoPlugins()
    const { layout, disabled } = migrate({
        rightLayout: ["plugins", "network", "power", "logs", "notifications"],
        order: ["nikos.timezones"], plugins: ps
    })
    assert.deepEqual(layout.left, ["velocity.logo", "velocity.workspaces"])
    assert.deepEqual(layout.center, ["nikos.clock"])
    assert.equal(layout.right[0], "nikos.timezones")
    assert.deepEqual(layout.right.slice(-3), ["velocity.network", "velocity.logs", "velocity.notifications"])
    assert.ok(layout.right.indexOf("velocity.power") === -1)
    assert.deepEqual(disabled.sort(), ["velocity.bluetooth", "velocity.privacy", "velocity.settings", "velocity.volume"])
})

ok("migrate: no/garbage rightLayout → legacy default, nothing disabled", () => {
    for (const rl of [undefined, [], ["bogus"]]) {
        const { layout, disabled } = migrate({ rightLayout: rl, order: [], plugins: [W("a.x")] })
        assert.deepEqual(layout.right, ["a.x"].concat(BUILTIN_IDS.slice(2)))
        assert.deepEqual(disabled, [])
    }
})

ok("migrate: committed state fixture stays schema-2-valid; legacy config still migrates clean", () => {
    // Both legs read COMMITTED fixtures: the repo-root bar-config.json and
    // plugins-state.json are runtime state (gitignored — clean clones, and
    // therefore `nix flake check`, have neither), and a test pinned to
    // mutable runtime state breaks the moment the live file drifts. The LIVE
    // stale-id gate over the real plugins-state.json lives in
    // tools/check-plugins, which skips clones where the bar has not created
    // the file yet.
    const here = dirname(fileURLToPath(import.meta.url))
    const cfg = JSON.parse(readFileSync(join(here, "fixtures", "bar-config.json"), "utf8"))
    const state = JSON.parse(readFileSync(join(here, "fixtures", "plugins-state.json"), "utf8"))
    assert.equal(state.schemaVersion, 2)

    // The old equality contract (migrate(bar-config) == plugins-state) is gone
    // by design: plugins-state.json is the bar's runtime-owned arrangement —
    // the settings app and CLI move widgets through the plugins IPC, and the
    // legacy bar-config schema cannot even express center placement. What must
    // hold instead:
    const layout = normalize(state.layout)
    for (const s of ["left", "center", "right"]) assert.ok(Array.isArray(layout[s]), s)

    // The legacy path still migrates clean from the committed bar-config.
    const { disabled } = migrate({ rightLayout: cfg.rightLayout, order: [], plugins: repoPlugins() })
    assert.deepEqual(disabled, [])
})

// ── pruneGrace (S4): unknown ids survive PRUNE_GRACE consecutive scans ──────
ok("pruneGrace: miss tally, drop at grace, reset on return", () => {
    const en = { "a.live": true, "z.gone": true }
    const lay = { left: [], center: [], right: ["a.live", "z.gone"] }

    // Scan 1: z.gone missing → miss 1, everything survives.
    let g = pruneGrace(en, lay, ["a.live"], {})
    assert.equal(PRUNE_GRACE, 3)
    assert.deepEqual(g.dropped, [])
    assert.deepEqual(g.misses, { "z.gone": 1 })
    assert.deepEqual(g.enabled, en)
    assert.deepEqual(g.layout, lay)

    // Scan 2: miss 2, still survives.
    g = pruneGrace(en, lay, ["a.live"], g.misses)
    assert.deepEqual(g.dropped, [])
    assert.deepEqual(g.misses, { "z.gone": 2 })

    // Scan 3: grace exhausted → dropped from enabled AND layout.
    g = pruneGrace(en, lay, ["a.live"], g.misses)
    assert.deepEqual(g.dropped, ["z.gone"])
    assert.deepEqual(g.enabled, { "a.live": true })
    assert.deepEqual(g.layout, { left: [], center: [], right: ["a.live"] })
    assert.deepEqual(g.misses, {})

    // The plugin returns → tally resets (misses map forgets it entirely).
    g = pruneGrace(en, lay, ["a.live", "z.gone"], { "z.gone": 2 })
    assert.deepEqual(g.dropped, [])
    assert.deepEqual(g.misses, {})
    assert.deepEqual(g.enabled, en)
})

ok("pruneGrace: layout-only ids tracked too; enabled+layout union counts ONE miss", () => {
    // Placed but never in enabledMap (e.g. disabled rows keep their place).
    let g = pruneGrace({}, { left: [], center: [], right: ["solo"] }, [], {})
    assert.deepEqual(g.misses, { solo: 1 })
    // Same id in enabled AND layout: one tally entry, not two.
    g = pruneGrace({ duo: true }, { left: [], center: [], right: ["duo"] }, [], {})
    assert.deepEqual(g.misses, { duo: 1 })
    // Grace parameter override: 1 = drop on the first miss.
    g = pruneGrace({ x: true }, { left: [], center: [], right: ["x"] }, [], {}, 1)
    assert.deepEqual(g.dropped, ["x"])
    assert.deepEqual(g.enabled, {})
})

// ── diffIdLists (P1): minimal apply-in-order ops for the BarSection model ───
function applyOps(list, ops) {
    const out = list.slice()
    for (const o of ops) {
        if (o.op === "remove") out.splice(o.index, 1)
        else out.splice(o.index, 0, o.id)
    }
    return out
}
ok("diffIdLists: identity-blind, no-op on equal content", () => {
    assert.deepEqual(diffIdLists(["a", "b"], ["a", "b"]), [])
    assert.deepEqual(diffIdLists([], []), [])
    assert.deepEqual(diffIdLists(null, []), [])
    // Same ids in fresh record wrappers → still no ops (id comparison).
    const ids = diffIdLists(["a", "b"], ["a", "b"].map(x => x + ""))
    assert.deepEqual(ids, [])
})

ok("diffIdLists: append / prepend / remove / middle insert", () => {
    let ops = diffIdLists(["a"], ["a", "b"])
    assert.deepEqual(applyOps(["a"], ops), ["a", "b"])
    ops = diffIdLists(["a"], ["z", "a"])
    assert.deepEqual(applyOps(["a"], ops), ["z", "a"])
    ops = diffIdLists(["a", "b", "c"], ["a", "c"])
    assert.deepEqual(applyOps(["a", "b", "c"], ops), ["a", "c"])
    ops = diffIdLists(["a", "c"], ["a", "b", "c"])
    assert.deepEqual(applyOps(["a", "c"], ops), ["a", "b", "c"])
})

ok("diffIdLists: moves land as remove+insert, any distance", () => {
    for (const [from, to] of [
        [["a", "b", "c"], ["c", "a", "b"]],
        [["a", "b", "c", "d"], ["d", "c", "b", "a"]],
        [["a", "b", "c"], ["b", "a", "c"]],
        [["a"], ["a"]],
        [[], ["x", "y"]],
        [["x", "y"], []],
    ]) {
        const ops = diffIdLists(from, to)
        assert.deepEqual(applyOps(from, ops), to, JSON.stringify({ from, to, ops }))
    }
})

ok("diffIdLists: remove+insert combined churn stays correct", () => {
    const from = ["a", "dead", "b", "c"]
    const to = ["c", "new", "a", "b"]
    const ops = diffIdLists(from, to)
    assert.deepEqual(applyOps(from, ops), to)
    // Removes all come before inserts in the op stream.
    const firstInsert = ops.findIndex(o => o.op === "insert")
    assert.ok(ops.slice(0, firstInsert).every(o => o.op === "remove"), "removes precede inserts")
})

console.log(`layout.test: ${n} passed`)
