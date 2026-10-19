// velocity-plugin.test.mjs — the CLI end to end in a throwaway XDG tree, with
// a fake `qs` that records the IPC argv (no bar needed).
import { strict as assert } from "node:assert"
import { spawnSync } from "node:child_process"
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, readdirSync, rmSync, chmodSync } from "node:fs"
import { join, dirname } from "node:path"
import { tmpdir } from "node:os"
import { fileURLToPath } from "node:url"

const CLI = join(dirname(fileURLToPath(import.meta.url)), "velocity-plugin")
const T = mkdtempSync(join(tmpdir(), "vp-test."))
const QS = join(T, "qs")
const LOG = join(T, "ipc.log")
writeFileSync(QS, `#!/bin/sh\necho "$*" >> "${LOG}"\necho ok\n`)
chmodSync(QS, 0o755)
const ENV = Object.assign({}, process.env, {
    XDG_CONFIG_HOME: join(T, "config"), XDG_DATA_HOME: join(T, "data"),
    XDG_STATE_HOME: join(T, "state"), XDG_DATA_DIRS: join(T, "sys"), VELOCITY_QS: QS
})
const USER = join(T, "config/velocity/plugins")
const vp = (...args) => spawnSync(CLI, args, { env: ENV, encoding: "utf8" })
const ipcLog = () => (existsSync(LOG) ? readFileSync(LOG, "utf8").trim().split("\n") : [])

let n = 0
function ok(name, fn) { fn(); n++; console.log("  ok " + name) }

try {
    ok("new: every kind scaffolds a valid plugin and asks the bar to enable it", () => {
        for (const [id, kind] of [["test.demo", "bar-widget"], ["test.ov", "overlay"], ["test.svc", "service"]]) {
            const r = vp("new", id, "--kind", kind)
            assert.equal(r.status, 0, r.stderr)
            assert.equal(vp("validate", id).status, 0)
        }
        assert.ok(ipcLog().includes("-c bar ipc call plugins enable test.svc"))
        assert.equal(vp("new", "test.demo").status, 1)
        assert.equal(vp("new", "bad").status, 1)
        assert.equal(vp("new", "test.xx", "--kind", "nope").status, 1)
    })

    ok("list shows sources and the user override shadowing a bundled copy", () => {
        assert.equal(vp("clone", "nikos.clock").status, 0)
        const ps = JSON.parse(vp("list", "--json").stdout)
        const clocks = ps.filter(p => p.id === "nikos.clock")
        assert.deepEqual(clocks.map(p => p.source + ":" + p.status), ["user:ready", "bundled:shadowed"])
        assert.ok(ps.some(p => p.id === "velocity.network" && p.source === "builtin" && p.enabled))
    })

    ok("remove → trash → restore round-trips; built-ins refuse removal", () => {
        assert.equal(vp("remove", "test.demo").status, 0)
        assert.ok(!existsSync(join(USER, "test.demo")))
        const trash = JSON.parse(vp("trash", "--json").stdout)
        assert.equal(trash[0].id, "test.demo")
        assert.equal(vp("restore", "test.demo").status, 0)
        assert.ok(existsSync(join(USER, "test.demo/manifest.json")))
        assert.ok(!existsSync(join(USER, "test.demo/.velocity-origin")))
        assert.equal(vp("remove", "velocity.network").status, 1)
        assert.equal(vp("restore", "nothing.here").status, 1)
    })

    ok("install from git: validates, refuses duplicates, converts Quattro, cleans up", () => {
        const temps = () => readdirSync(tmpdir()).filter(d => d.indexOf("velocity-plugin.") === 0).length
        const before = temps()
        const repo = (name, files) => {
            const d = join(T, "src-" + name)
            mkdirSync(d, { recursive: true })
            for (const f in files) writeFileSync(join(d, f), files[f])
            const g = (...a) => spawnSync("git", a, { cwd: d })
            g("init", "-q"); g("add", "-A"); g("-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "x")
            return d
        }
        const good = repo("good", {
            "manifest.json": JSON.stringify({ schemaVersion: 2, api: 2, id: "acme.good", name: "G", version: "1", kinds: ["bar-widget"], entryPoints: { barWidget: "W.qml" } }),
            "W.qml": "import QtQuick\nItem {}\n"
        })
        assert.equal(vp("install", good).status, 0)
        assert.ok(!existsSync(join(USER, "acme.good/.git")))
        assert.equal(vp("install", good).status, 1)
        const quat = repo("quat", {
            "manifest.json": JSON.stringify({ id: "acme.quat", name: "Q", version: "1", kinds: ["bar-widget"] }),
            "BarWidget.qml": "import QtQuick\nBarWidget {\n}\n"
        })
        assert.equal(vp("install", quat).status, 0)
        const w = readFileSync(join(USER, "acme.quat/BarWidget.qml"), "utf8")
        assert.match(w, /^import qs\.Ui$/m)
        assert.match(w, /^QsBarWidget \{$/m)
        assert.ok(existsSync(join(USER, "acme.quat/manifest.quattro.json")))
        const api1 = repo("api1", {
            "manifest.json": JSON.stringify({ schemaVersion: 1, api: 1, id: "acme.old", name: "O", version: "1", kinds: ["bar-widget"], entryPoints: { barWidget: "W.qml" } }),
            "W.qml": "import QtQuick\nItem {}\n"
        })
        assert.equal(vp("install", api1).status, 1)
        assert.ok(!existsSync(join(USER, "acme.old")))
        assert.equal(temps(), before)
    })

    ok("state verbs forward flag-safe argv to the bar", () => {
        writeFileSync(LOG, "")
        vp("place", "test.demo", "left"); vp("place", "test.demo", "center", "2")
        vp("move", "test.demo", "-1"); vp("move", "test.demo", "3")
        vp("set", "test.demo", "label", '"HI"'); vp("reload", "test.demo")
        assert.deepEqual(ipcLog(), [
            "-c bar ipc call plugins place test.demo left end",
            "-c bar ipc call plugins place test.demo center 2",
            "-c bar ipc call plugins move test.demo up",
            "-c bar ipc call plugins move test.demo down3",
            "-c bar ipc call plugins setSetting test.demo label \"HI\"",
            "-c bar ipc call plugins reload test.demo"
        ])
        assert.equal(vp("place", "test.demo", "top").status, 1)
        assert.equal(vp("move", "test.demo", "0").status, 1)
        assert.equal(vp("set", "test.demo", "label", "HI").status, 1)
        assert.equal(vp("bogus").status, 2)
    })

    ok("bar offline: state verbs explain, file verbs still work", () => {
        const off = Object.assign({}, ENV, { VELOCITY_QS: join(T, "missing-qs") })
        const r = spawnSync(CLI, ["enable", "test.demo"], { env: off, encoding: "utf8" })
        assert.equal(r.status, 1)
        assert.match(r.stderr, /bar not reachable/)
        const n2 = spawnSync(CLI, ["new", "test.offline"], { env: off, encoding: "utf8" })
        assert.equal(n2.status, 0)
        assert.match(n2.stdout, /velocity-plugin enable test.offline/)
    })

    ok("every `velocity-plugin <cmd>` in plugins/README.md is a real command", () => {
        const doc = readFileSync(join(dirname(CLI), "../plugins/README.md"), "utf8")
        const cmds = [...new Set([...doc.matchAll(/velocity-plugin ([a-z]+)/g)].map(m => m[1]))]
        assert.ok(cmds.length >= 15, "doc mentions " + cmds.length + " commands")
        for (const c of cmds) assert.doesNotMatch(vp(c).stderr, /unknown command/, c)
    })
} finally {
    rmSync(T, { recursive: true, force: true })
}

console.log(`velocity-plugin.test: ${n} passed`)
