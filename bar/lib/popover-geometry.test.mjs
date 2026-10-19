// popover-geometry.test.mjs — clamp math behind Popover.qml (UA 2.2).
import { strict as assert } from "node:assert"
import { clampCardWidth, clampMaxHeight, scrollNeeded } from "./popover-geometry.mjs"

let n = 0
function ok(name, fn) { fn(); n++; console.log("  ok " + name) }

ok("width: wider than screen clamps to parent minus margins", () =>
    assert.equal(clampCardWidth(900, 600, 5), 590))
ok("width: normal card inside a big screen stays at request", () =>
    assert.equal(clampCardWidth(320, 1920, 5), 320))
ok("width: tiny parent floors at MIN_CARD", () =>
    assert.equal(clampCardWidth(320, 4, 5), 1))
ok("width: unknown parent keeps the request (pre-attach)", () =>
    assert.equal(clampCardWidth(320, 0, 5), 320))
ok("width: junk request floors at MIN_CARD like any degenerate width", () =>
    assert.equal(clampCardWidth(undefined, 1920, 5), 1))

ok("maxHeight: budget = parent - gap - 2*margin", () =>
    assert.equal(clampMaxHeight(700, 8, 5), 682))
ok("maxHeight: 800px-tall host on a small screen", () =>
    assert.equal(clampMaxHeight(430, 8, 5), 412))
ok("maxHeight: over-budget floors at MIN_CARD", () =>
    assert.equal(clampMaxHeight(6, 8, 5), 1))
ok("maxHeight: unknown parent → unclamped (-1)", () =>
    assert.equal(clampMaxHeight(0, 8, 5), -1))

ok("scroll: taller content needs scroll", () =>
    assert.equal(scrollNeeded(900, 682), true))
ok("scroll: exact-fit content does not (1px rounding guard)", () =>
    assert.equal(scrollNeeded(683, 682), false))
ok("scroll: shorter content does not", () =>
    assert.equal(scrollNeeded(100, 682), false))

console.log("popover-geometry: " + n + " assertions passed")
