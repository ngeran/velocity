// tier.test.mjs — threshold contract for the severity ramp key selection.
import { strict as assert } from "node:assert"
import { tierFor } from "./tier.mjs"

let n = 0
function ok(name, fn) { fn(); n++; console.log("  ok " + name) }

ok("cool below warn", () => assert.equal(tierFor(41, 70, 85), "secondary"))
ok("warn at boundary (inclusive)", () => assert.equal(tierFor(70, 70, 85), "warning"))
ok("crit at boundary (inclusive)", () => assert.equal(tierFor(85, 70, 85), "error"))
ok("over crit", () => assert.equal(tierFor(99, 70, 85), "error"))
ok("NaN reads calm (sensor absent)", () => assert.equal(tierFor(NaN, 70, 85), "secondary"))
ok("negative reads calm", () => assert.equal(tierFor(-1, 70, 85), "secondary"))

console.log("tier: " + n + " assertions passed")
