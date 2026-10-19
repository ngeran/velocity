// settings.test.mjs — schema validation, defaults, coercion, merge.
import { strict as assert } from "node:assert"
import { coerce, validateSchema, defaultsFor, merge, changedKeys } from "./settings.mjs"

let n = 0
function ok(name, fn) { fn(); n++; console.log("  ok " + name) }

const SCHEMA = {
    city: { type: "string", default: "Athens" },
    refresh: { type: "number", default: 600, min: 60, max: 3600 },
    osd: { type: "bool", default: true },
    units: { type: "enum", default: "metric", options: ["metric", "imperial"] },
    zones: { type: "list", default: ["Europe/Athens"] }
}

ok("a full schema validates and yields its defaults", () => {
    assert.deepEqual(validateSchema(SCHEMA), [])
    assert.deepEqual(defaultsFor(SCHEMA), { city: "Athens", refresh: 600, osd: true, units: "metric", zones: ["Europe/Athens"] })
})

ok("schema errors name the key", () => {
    const errs = validateSchema({
        "bad key": { type: "string", default: "" },
        a: { type: "color", default: "#fff" },
        b: { type: "enum", default: "x" },
        c: { type: "number" },
        d: { type: "number", default: 5, min: 10 }
    }).join(" | ")
    assert.match(errs, /settings.bad key: key must be an identifier/)
    assert.match(errs, /settings.a.type must be one of/)
    assert.match(errs, /settings.b.options must be a non-empty array/)
    assert.match(errs, /settings.c.default missing/)
    assert.match(errs, /settings.d.default invalid: below min 10/)
    assert.deepEqual(validateSchema(undefined), [])
    assert.equal(validateSchema([]).length, 1)
})

ok("coercion is strict for numbers/bools/enums/lists", () => {
    assert.deepEqual(coerce(SCHEMA.refresh, "120"), { ok: true, value: 120 })
    assert.equal(coerce(SCHEMA.refresh, "abc").ok, false)
    assert.equal(coerce(SCHEMA.refresh, true).ok, false)
    assert.equal(coerce(SCHEMA.refresh, 30).ok, false)
    assert.deepEqual(coerce(SCHEMA.osd, "false"), { ok: true, value: false })
    assert.equal(coerce(SCHEMA.osd, 1).ok, false)
    assert.equal(coerce(SCHEMA.units, "kelvin").ok, false)
    assert.equal(coerce(SCHEMA.zones, ["a", 2]).ok, false)
    assert.deepEqual(coerce(SCHEMA.city, 42), { ok: true, value: "42" })
})

ok("merge: stored overrides defaults, bad stored values fall back, extras pass through", () => {
    const v = merge(SCHEMA, { city: "Tokyo", refresh: 5, units: "imperial", prefs: { a: 1 } })
    assert.equal(v.city, "Tokyo")
    assert.equal(v.refresh, 600)
    assert.equal(v.units, "imperial")
    assert.deepEqual(v.prefs, { a: 1 })
    assert.deepEqual(merge(SCHEMA, null), defaultsFor(SCHEMA))
    assert.deepEqual(merge(undefined, { x: 1 }), { x: 1 })
})

ok("changedKeys finds added, removed and changed keys", () => {
    assert.deepEqual(changedKeys({ a: 1, b: [1], c: 3 }, { a: 1, b: [2], d: 4 }).sort(), ["b", "c", "d"])
    assert.deepEqual(changedKeys({ a: [1] }, { a: [1] }), [])
})

console.log(`settings.test: ${n} passed`)
