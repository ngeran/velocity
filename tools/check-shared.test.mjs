// check-shared.test.mjs — GENERATED-stamp contract of the sync-shared /
// check-shared pair, exercised end-to-end in a throwaway mini-repo (the tools
// are imperative CommonJS, so the fixture spawns the real scripts rather than
// importing them).
import { strict as assert } from "node:assert"
import { spawnSync } from "node:child_process"
import { mkdtempSync, mkdirSync, copyFileSync, writeFileSync, readFileSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { join, dirname } from "node:path"
import { fileURLToPath } from "node:url"

const REPO = join(dirname(fileURLToPath(import.meta.url)), "..")
const SYNC = join(REPO, "tools", "sync-shared")
const CHECK = join(REPO, "tools", "check-shared")

let n = 0
function ok(name, fn) { fn(); n++; console.log("  ok " + name) }

// Fresh mini-repo: same relative layout the tools expect (root = script dir/..).
function fixture(srcBody) {
    const root = mkdtempSync(join(tmpdir(), "velocity-shared-"))
    mkdirSync(join(root, "tools"))
    mkdirSync(join(root, "shared"))
    mkdirSync(join(root, "bar", "lib"), { recursive: true })
    mkdirSync(join(root, "settings", "lib"), { recursive: true })
    copyFileSync(SYNC, join(root, "tools", "sync-shared"))
    copyFileSync(CHECK, join(root, "tools", "check-shared"))
    writeFileSync(join(root, "tools", "shared-targets.js"),
        "module.exports = { 'shared/units.mjs': ['bar/lib/units.mjs', 'settings/lib/units.mjs'] }\n")
    writeFileSync(join(root, "shared", "units.mjs"), srcBody)
    return root
}

const run = (root, script) =>
    spawnSync(process.execPath, [script], { cwd: root, encoding: "utf8" })

const SRC = "export const c2f = (c) => c * 9 / 5 + 32\n"
const stampLine = (src) => `// GENERATED from ${src} by tools/sync-shared — do not edit\n`

ok("sync-shared stamps line 1 and copies the rest byte-identical", () => {
    const root = fixture(SRC)
    try {
        const r = run(root, join(root, "tools", "sync-shared"))
        assert.equal(r.status, 0, r.stderr)
        for (const dst of ["bar/lib/units.mjs", "settings/lib/units.mjs"]) {
            const buf = readFileSync(join(root, dst))
            assert.equal(buf.slice(0, buf.indexOf(10)).toString("utf8") + "\n", stampLine("shared/units.mjs"))
            assert.equal(buf.slice(buf.indexOf(10) + 1).toString("utf8"), SRC)
        }
    } finally { rmSync(root, { recursive: true, force: true }) }
})

ok("check-shared: stamped fresh copy passes; re-sync is idempotent", () => {
    const root = fixture(SRC)
    try {
        assert.equal(run(root, join(root, "tools", "sync-shared")).status, 0)
        const c1 = run(root, join(root, "tools", "check-shared"))
        assert.equal(c1.status, 0, c1.stderr)
        assert.ok(c1.stdout.trimEnd().endsWith("check-shared: OK"))
        assert.equal(run(root, join(root, "tools", "sync-shared")).status, 0)
        assert.equal(run(root, join(root, "tools", "check-shared")).status, 0)
    } finally { rmSync(root, { recursive: true, force: true }) }
})

ok("check-shared fails on missing stamp, stale stamp, drift, missing copy, missing canonical", () => {
    const root = fixture(SRC)
    try {
        const dstPath = join(root, "bar", "lib", "units.mjs")
        assert.equal(run(root, join(root, "tools", "sync-shared")).status, 0)

        const buf = readFileSync(dstPath)
        const body = buf.slice(buf.indexOf(10) + 1)

        // hand-edited copy that dropped the stamp
        writeFileSync(dstPath, body)
        let c = run(root, join(root, "tools", "check-shared"))
        assert.equal(c.status, 1)
        assert.ok(/stamp/.test(c.stderr))

        // stamp pointing at the wrong source
        writeFileSync(dstPath, Buffer.concat([Buffer.from(stampLine("shared/other.mjs")), body]))
        c = run(root, join(root, "tools", "check-shared"))
        assert.equal(c.status, 1)
        assert.ok(/stamp/.test(c.stderr))

        // real stamp, drifted body (the classic root-copy hand-edit)
        writeFileSync(dstPath, Buffer.concat([Buffer.from(stampLine("shared/units.mjs")), Buffer.from(SRC + "// tweak\n")]))
        c = run(root, join(root, "tools", "check-shared"))
        assert.equal(c.status, 1)
        assert.ok(/DRIFT/.test(c.stderr))

        // copy deleted entirely
        rmSync(dstPath)
        c = run(root, join(root, "tools", "check-shared"))
        assert.equal(c.status, 1)
        assert.ok(/missing/.test(c.stderr))

        // canonical file gone
        writeFileSync(dstPath, Buffer.concat([Buffer.from(stampLine("shared/units.mjs")), body]))
        rmSync(join(root, "shared", "units.mjs"))
        c = run(root, join(root, "tools", "check-shared"))
        assert.equal(c.status, 1)
        assert.ok(/canonical/.test(c.stderr))
    } finally { rmSync(root, { recursive: true, force: true }) }
})

console.log(`check-shared.test.mjs: ${n} ok`)
