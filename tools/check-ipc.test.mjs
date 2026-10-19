// check-ipc.test.mjs — fixture tests for tools/check-ipc's argv-array caller
// extraction (spawn-string callers were always covered; `ctx.run(["qs","-c",
// PROC,"ipc","call",TARGET,FN])` lines used to be invisible to the gate).
// Run: tools/run-unit-tests (auto-discovered; plain node, no framework).
import { spawnSync } from "node:child_process"
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { join, dirname } from "node:path"
import assert from "node:assert/strict"
import { fileURLToPath } from "node:url"

const CHECK = join(dirname(fileURLToPath(import.meta.url)), "check-ipc")

let n = 0
function fixture(withCaller, { target = "TestTarget", fn = "alpha", declared = "alpha" } = {}) {
    const root = mkdtempSync(join(tmpdir(), "check-ipc-fixture-"))
    mkdirSync(join(root, "bar"))
    mkdirSync(join(root, "settings"))          // DECLARED scan expects both dirs
    mkdirSync(join(root, "omni", "configs", "hypr"), { recursive: true })
    writeFileSync(join(root, "omni", "configs", "hypr", "keybindings.lua"), "# no binds\n")
    writeFileSync(join(root, "bar", "shell.qml"), `// fixture\nIpcHandler {\n    target: "${target}"\n    function ${declared}() {}\n}\n`)
    if (withCaller) {
        mkdirSync(join(root, "caller"))
        writeFileSync(join(root, "caller", "widget.qml"),
            `// fixture\nctx.run(["quickshell", "-c", "bar", "ipc", "call", "${target}", "${fn}"])\n`)
    }
    writeFileSync(join(root, "surface.txt"), `${target}.${declared} internal\n`)
    return root
}

function run(root) {
    return spawnSync("bash", [CHECK], {
        encoding: "utf8",
        env: {
            ...process.env,
            IPC_QS_DIR: root,
            IPC_OMNI_DIR: join(root, "omni"),
            IPC_SURFACE: join(root, "surface.txt"),
        },
    })
}

// 1. argv-array caller is recognized → internal pair passes.
{
    const root = fixture(true)
    try {
        const r = run(root)
        n++
        assert.equal(r.status, 0, "argv caller should satisfy the internal class; stderr: " + r.stderr)
        n++
        assert.match(r.stdout, /1 used/, "argv caller must be counted in USED")
    } finally { rmSync(root, { recursive: true, force: true }) }
}

// 2. internal pair with NO call site at all → hard failure (unchanged rule).
{
    const root = fixture(false)
    try {
        const r = run(root)
        n++
        assert.equal(r.status, 1, "internal without call site must fail")
        n++
        assert.match(r.stderr, /marked internal but no repo call site/, "must name the reason")
    } finally { rmSync(root, { recursive: true, force: true }) }
}

// 3. argv-array caller to an UNDECLARED function → hard failure (silent no-op).
{
    const root = fixture(true, { fn: "nosuch" })
    try {
        const r = run(root)
        n++
        assert.equal(r.status, 1, "argv caller to undeclared fn must fail")
        n++
        assert.match(r.stderr, /caller 'bar' dispatches to undeclared handler 'TestTarget\.nosuch'/)
    } finally { rmSync(root, { recursive: true, force: true }) }
}

// 4. the second element order ("ipc" before "-c", Header.qml form) is found too.
{
    const root = fixture(true)
    writeFileSync(join(root, "caller", "widget.qml"),
        `// fixture\ncommand: ["quickshell", "ipc", "-c", "bar", "call", "TestTarget", "alpha"]\n`)
    try {
        const r = run(root)
        n++
        assert.equal(r.status, 0, "ipc-first argv order should satisfy the internal class; stderr: " + r.stderr)
        n++
        assert.match(r.stdout, /1 used/, "ipc-first argv caller must be counted")
    } finally { rmSync(root, { recursive: true, force: true }) }
}

console.log(`check-ipc.test.mjs: OK (${n} assertions)`)
