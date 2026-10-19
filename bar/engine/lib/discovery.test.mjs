// discovery.test.mjs — scan parsing, precedence and symlink rules.
import { strict as assert } from "node:assert"
import { parseScanOutput, resolvePlugins } from "./discovery.mjs"

let n = 0
function ok(name, fn) { fn(); n++; console.log("  ok " + name) }

const m = (id, extra) => JSON.stringify(Object.assign({
    schemaVersion: 1, api: 1, id, name: id, version: "1",
    kinds: ["bar-widget"], entryPoints: { barWidget: "BarWidget.qml" }
}, extra || {}))

// Shape the real scan script prints (verified against it in /tmp fixtures).
const RAW = [
    "@DIR user /u/a.dup/", m("a.dup", { name: "User copy" }), "",
    "@DIR system /s/a.nix/", m("a.nix"), "",
    "@DIR bundled /b/a.dup/", m("a.dup"), "",
    "@DIR bundled /b/a.linked/", m("a.linked"), "",
    "@DIR bundled /b/broken/", "{ nope", "",
    "@LINK /b/a.linked/evil", ""
].join("\n")

ok("parses blocks in order and collects links", () => {
    const { blocks, symlinks } = parseScanOutput(RAW)
    assert.deepEqual(blocks.map(b => b.source + ":" + b.dir),
        ["user:/u/a.dup/", "system:/s/a.nix/", "bundled:/b/a.dup/", "bundled:/b/a.linked/", "bundled:/b/broken/"])
    assert.deepEqual(symlinks, ["/b/a.linked/evil"])
})

const { blocks, symlinks } = parseScanOutput(RAW)
const list = resolvePlugins(blocks, symlinks, 1)
const at = dir => list.find(p => p.dir === dir)

ok("higher-precedence copy wins and records what it overrides", () => {
    assert.equal(at("/u/a.dup/").status, "disabled")
    assert.equal(at("/u/a.dup/").name, "User copy")
    assert.deepEqual(at("/u/a.dup/").overrides, ["/b/a.dup/"])
    assert.equal(at("/b/a.dup/").status, "shadowed")
    assert.match(at("/b/a.dup/").error, /overridden by \/u\/a.dup\//)
})

ok("symlinks reject only the plugin that contains them", () => {
    assert.equal(at("/b/a.linked/").status, "invalid")
    assert.match(at("/b/a.linked/").error, /symlink: \/b\/a.linked\/evil/)
    assert.equal(at("/s/a.nix/").status, "disabled")
})

ok("broken manifests are listed as invalid, keyed by their dir", () => {
    assert.equal(at("/b/broken/").status, "invalid")
    assert.equal(at("/b/broken/").id, "/b/broken/")
    assert.match(at("/b/broken/").error, /not valid JSON/)
})

ok("an invalid higher copy does not shadow a valid lower one", () => {
    const raw = ["@DIR user /u/x.y2/", "{ bad", "@DIR bundled /b/x.y2/", m("x.y2"), ""].join("\n")
    const r = parseScanOutput(raw)
    const l = resolvePlugins(r.blocks, r.symlinks, 1)
    assert.equal(l[0].status, "invalid")
    assert.equal(l[1].status, "disabled")
})

ok("every valid plugin starts disabled (opt-in; state decides)", () => {
    assert.ok(list.filter(p => p.status !== "invalid" && p.status !== "shadowed").every(p => p.enabled === false))
})

console.log(`discovery.test: ${n} passed`)
