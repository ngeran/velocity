// theme-mix.test.mjs — runs the SAME suite against BOTH process copies
// (bar + settings). They must stay behaviorally identical; a change applied to
// one copy but not the other fails here (drift check).
import { strict as assert } from "node:assert"
import * as bar from "./theme-mix.mjs"
import * as settings from "../../settings/lib/theme-mix.mjs"

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

suite(bar, "bar")
suite(settings, "settings")

ok("exports identical across copies", () => {
    const a = Object.keys(bar).sort().join(",")
    const b = Object.keys(settings).sort().join(",")
    assert.equal(a, b)
})

console.log("theme-mix: " + n + " assertions passed (both copies)")
