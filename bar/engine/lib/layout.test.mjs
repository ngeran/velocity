// layout.test.mjs — layout normalize/place/move/resolve + schema-1 migration.
import { strict as assert } from "node:assert"
import { readFileSync, readdirSync, existsSync } from "node:fs"
import { join, dirname } from "node:path"
import { fileURLToPath } from "node:url"
import { normalize, place, remove, move, prune, sectionOf, ensurePlaced, resolve, migrate, BUILTIN_IDS } from "./layout.mjs"
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

ok("migrate: state stays schema-2-valid with no stale ids; legacy config still migrates clean", () => {
    // Legacy-config leg reads a COMMITTED fixture: the repo-root
    // bar-config.json is runtime state (gitignored — clean clones, and
    // therefore `nix flake check`, don't have it), and a test pinned to
    // mutable runtime state breaks the moment the live config drifts.
    // The schema-2 leg keeps reading the tracked plugins-state.json: that
    // file IS the bar's committed arrangement and the stale-id gate is
    // deliberately live.
    const here = dirname(fileURLToPath(import.meta.url))
    const cfg = JSON.parse(readFileSync(join(here, "fixtures", "bar-config.json"), "utf8"))
    const state = JSON.parse(readFileSync(join(root, "plugins-state.json"), "utf8"))
    assert.equal(state.schemaVersion, 2)

    // The old equality contract (migrate(bar-config) == plugins-state) is gone
    // by design: plugins-state.json is the bar's runtime-owned arrangement —
    // the settings app and CLI move widgets through the plugins IPC, and the
    // legacy bar-config schema cannot even express center placement. What must
    // hold instead:
    const layout = normalize(state.layout)
    for (const s of ["left", "center", "right"]) assert.ok(Array.isArray(layout[s]), s)

    // Every committed id is a real plugin or builtin. resolve() tolerates
    // stale ids at runtime, but the committed file must not accumulate them —
    // the bar prunes on its own writes; this keeps the gate honest.
    const known = new Set(BUILTIN_IDS)
    for (const p of repoPlugins()) known.add(p.id)
    for (const s of ["left", "center", "right"])
        for (const id of layout[s]) assert.ok(known.has(id), "stale id in committed state: " + id)

    // The legacy path still migrates clean from the committed bar-config.
    const { disabled } = migrate({ rightLayout: cfg.rightLayout, order: [], plugins: repoPlugins() })
    assert.deepEqual(disabled, [])
})

console.log(`layout.test: ${n} passed`)
