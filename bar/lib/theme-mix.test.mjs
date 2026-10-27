// theme-mix.test.mjs — behavioral suite for the CANONICAL shared/theme-mix.mjs,
// plus byte-identity checks on the per-root copies sync-shared distributes
// (bar/lib + settings/lib). Behavior lives in one place; the copies must never
// diverge from it (check-shared enforces the same rule at gate level).
import { strict as assert } from "node:assert"
import { readFileSync } from "node:fs"
import { fileURLToPath } from "node:url"
import * as canonical from "../../shared/theme-mix.mjs"

const here = fileURLToPath(new URL(".", import.meta.url))

let n = 0
function ok(name, fn) { fn(); n++; console.log("  ok " + name) }

function suite(mod, label) {
    console.log("[" + label + "]")
    ok(label + ": parseHex roundtrip", () =>
        assert.deepEqual(mod.parseHex("#0a1b2c"), [0x0a, 0x1b, 0x2c]))
    ok(label + ": parseHex tolerates #rrggbbaa", () =>
        assert.deepEqual(mod.parseHex("#0a1b2cff"), [0x0a, 0x1b, 0x2c]))
    ok(label + ": parseHex rejects junk", () =>
        assert.equal(mod.parseHex("#zz"), null))
    ok(label + ": parseHex rejects non-strings", () =>
        assert.equal(mod.parseHex(42), null))
    ok(label + ": toHex clamps out-of-range channels", () =>
        assert.equal(mod.toHex(-5, 300, 128), "#00ff80"))
    ok(label + ": palettesEqual true on identical", () =>
        assert.equal(mod.palettesEqual({ a: "#111111" }, { a: "#111111" }), true))
    ok(label + ": palettesEqual false on value drift", () =>
        assert.equal(mod.palettesEqual({ a: "#111111" }, { a: "#222222" }), false))
    ok(label + ": palettesEqual false on missing key", () =>
        assert.equal(mod.palettesEqual({ a: "#111111" }, { a: "#111111", b: "#333333" }), false))
    ok(label + ": mix t=0 returns prev values", () => {
        const m = mod.mixPalettes({ a: [0, 0, 0] }, { a: "#ffffff" }, 0)
        assert.equal(m.a, "#000000")
    })
    ok(label + ": mix t=1 returns target exactly (string identity)", () => {
        const m = mod.mixPalettes({ a: [0, 0, 0] }, { a: "#aabbcc" }, 1)
        assert.equal(m.a, "#aabbcc")
    })
    ok(label + ": mix t=0.5 is the midpoint", () => {
        const m = mod.mixPalettes({ a: [0, 0, 0] }, { a: "#ffffff" }, 0.5)
        assert.equal(m.a, "#808080")   // 127.5 → clamp255 rounds to 128 = 0x80
    })
    ok(label + ": missing prev key falls through to target (never black)", () => {
        const m = mod.mixPalettes({}, { a: "#aabbcc" }, 0.3)
        assert.equal(m.a, "#aabbcc")
    })
    ok(label + ": unparseable target value passes through", () => {
        const m = mod.mixPalettes({ a: [1, 2, 3] }, { a: "not-hex" }, 0.5)
        assert.equal(m.a, "not-hex")
    })
    ok(label + ": t is clamped into [0,1]", () => {
        assert.equal(mod.mixPalettes({ a: [0, 0, 0] }, { a: "#ffffff" }, 9).a, "#ffffff")
        assert.equal(mod.mixPalettes({ a: [0, 0, 0] }, { a: "#ffffff" }, -9).a, "#000000")
    })
}

suite(canonical, "shared")

// Copies carry a line-1 GENERATED stamp (I3); compare everything after it.
// The global stamp-aware gate is tools/check-shared — these stay as the
// theme-mix-local redundancy.
const withoutStamp = (text) =>
    text.startsWith("// GENERATED from shared/") ? text.slice(text.indexOf("\n") + 1) : text

ok("bar copy byte-identical to canonical (past stamp)", () => {
    const a = readFileSync(here + "theme-mix.mjs", "utf8")
    const b = readFileSync(here + "../../shared/theme-mix.mjs", "utf8")
    assert.equal(withoutStamp(a), b)
})

ok("settings copy byte-identical to canonical (past stamp)", () => {
    const a = readFileSync(here + "../../settings/lib/theme-mix.mjs", "utf8")
    const b = readFileSync(here + "../../shared/theme-mix.mjs", "utf8")
    assert.equal(withoutStamp(a), b)
})

console.log("theme-mix: " + n + " assertions passed (canonical + 2 copies)")
