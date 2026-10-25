// manifest.test.mjs — the shared validator against real and broken manifests.
import { strict as assert } from "node:assert"
import { readFileSync, readdirSync, existsSync } from "node:fs"
import { join, dirname } from "node:path"
import { fileURLToPath } from "node:url"
import { validateManifest, parseManifest, entryKey } from "./manifest.mjs"

let n = 0
function ok(name, fn) { fn(); n++; console.log("  ok " + name) }

const base = () => ({
    schemaVersion: 1, api: 1, id: "nikos.demo", name: "Demo", version: "1.0.0",
    kinds: ["bar-widget"], entryPoints: { barWidget: "BarWidget.qml" }, commands: []
})
const errs = (m, o) => { const r = validateManifest(m, o || { hostApi: 1 }); assert.equal(r.ok, false); return r.errors.join(" | ") }

ok("minimal v1 manifest validates and normalizes", () => {
    const r = validateManifest(base(), { hostApi: 1 })
    assert.equal(r.ok, true)
    assert.equal(r.plugin.defaultSection, "right")
    assert.equal(r.plugin.author, "nikos")
    assert.deepEqual(r.plugin.ipc, [])
})

ok("multi-segment ids are legal (host and offline validator agree)", () => {
    assert.equal(validateManifest({ ...base(), id: "io.github.sspaeti.timezones" }, { hostApi: 1 }).ok, true)
})

ok("bad and reserved ids are rejected", () => {
    assert.match(errs({ ...base(), id: "NoNamespace" }), /namespaced/)
    assert.match(errs({ ...base(), id: "omarchy.clock" }), /reserved/)
})

ok("api gate: missing api = 1, mismatches name the host api", () => {
    const m = base(); delete m.api
    assert.equal(validateManifest(m, { hostApi: 1 }).ok, true)
    assert.match(errs({ ...base(), api: 2 }), /plugin newer than shell/)
    assert.match(errs(base(), { hostApi: 2 }), /this host provides api 2/)
})

ok("entry points must be safe and (offline) exist", () => {
    assert.match(errs({ ...base(), entryPoints: { barWidget: "../x.qml" } }), /safe relative filename/)
    assert.match(errs(base(), { hostApi: 1, fileExists: () => false }), /entry point file not found: 'BarWidget.qml'/)
    assert.match(errs({ ...base(), kinds: ["panel"] }), /unsupported kind: panel/)
    assert.equal(entryKey("bar-widget"), "barWidget")
    assert.equal(entryKey("overlay"), "overlay")
})

ok("extra entryPoints.service on a bar-widget: the service/view split root", () => {
    const m = { ...base(), entryPoints: { barWidget: "BarWidget.qml", service: "Service.qml" } }
    const r = validateManifest(m, { hostApi: 1, fileExists: () => true })
    assert.equal(r.ok, true)
    assert.equal(r.plugin.entryPoints.service, "Service.qml")
    assert.match(errs({ ...m, entryPoints: { barWidget: "BarWidget.qml", service: "../x.qml" } }), /entryPoints\.service must be a safe/)
    assert.match(errs({ ...m, entryPoints: { barWidget: "BarWidget.qml", service: "Nope.qml" } },
                      { hostApi: 1, fileExists: () => false }), /entry point file not found: 'Nope\.qml'/)
    // kind-service plugins keep validating service through the kinds loop
    assert.equal(validateManifest({ ...base(), kinds: ["service"], entryPoints: { service: "Service.qml" } },
                                  { hostApi: 1, fileExists: () => true }).ok, true)
})

ok("v2 bar.defaultSection: any section; v1 slot maps onto it", () => {
    const v2 = { ...base(), schemaVersion: 2, bar: { defaultSection: "center" }, ipc: ["next", "set"], settings: { city: { type: "string", default: "Athens" } } }
    const r = validateManifest(v2, { hostApi: 1 })
    assert.equal(r.ok, true)
    assert.equal(r.plugin.defaultSection, "center")
    assert.deepEqual(r.plugin.ipc, ["next", "set"])
    assert.equal(validateManifest({ ...v2, bar: { defaultSection: "left" } }, { hostApi: 1 }).plugin.defaultSection, "left")
    assert.equal(validateManifest({ ...base(), slot: "center" }, { hostApi: 1 }).plugin.defaultSection, "center")
    assert.match(errs({ ...v2, bar: { defaultSection: "top" } }), /defaultSection/)
    assert.match(errs({ ...v2, ipc: ["bad verb"] }), /ipc must be/)
})

ok("settings schema errors surface through the manifest", () => {
    assert.match(errs({ ...base(), settings: { city: { type: "string" } } }), /settings.city.default missing/)
    assert.match(errs({ ...base(), settings: [] }), /settings must be an object/)
})

ok("JSON errors are validation errors, not throws", () => {
    const r = parseManifest("{ nope", { hostApi: 1 })
    assert.equal(r.ok, false)
    assert.match(r.errors[0], /not valid JSON/)
})

ok("bar.collapsePriority: optional int, defaults to 50", () => {
    const m = () => ({ schemaVersion: 2, id: "a.bb", name: "n", version: "1", kinds: ["bar-widget"], entryPoints: { barWidget: "B.qml" } })
    assert.equal(parseManifest(JSON.stringify(m())).plugin.collapsePriority, 50)
    assert.equal(parseManifest(JSON.stringify({ ...m(), bar: { collapsePriority: 90 } })).plugin.collapsePriority, 90)
    for (const bad of ["x", 2.5, null])
        assert.match(errs({ ...m(), bar: { collapsePriority: bad } }), /collapsePriority must be an integer/)
})

ok("every in-repo plugin manifest validates offline", () => {
    const root = join(dirname(fileURLToPath(import.meta.url)), "../../../plugins")
    for (const d of readdirSync(root)) {
        const p = join(root, d, "manifest.json")
        if (!existsSync(p)) continue
        const r = parseManifest(readFileSync(p, "utf8"), { hostApi: 2, fileExists: f => existsSync(join(root, d, f)) })
        assert.equal(r.ok, true, d + ": " + (r.errors || []).join("; "))
    }
})

console.log(`manifest.test: ${n} passed`)
