// theme-ingest.test.mjs — node checks for shared/theme-ingest.mjs (P2.7).
// Run: tools/run-unit-tests (auto-discovered). Plain asserts, no framework.
import * as Ingest from "./theme-ingest.mjs";
import * as Core from "./theme-core.mjs";

let failed = 0;
function ok(cond, name) {
    if (cond) { console.log("  ok", name); }
    else { console.error("  FAIL", name); failed++; }
}
function eq(a, b, name) { ok(JSON.stringify(a) === JSON.stringify(b), name); }

// ── defaults ────────────────────────────────────────────────────────────────
ok(Object.keys(Ingest.DEFAULT_COLORS).length === 16, "16 color tokens");
ok(Ingest.DEFAULT_COLORS.surface === "#0a0a0a", "boot surface (NOT the writer seed — intentional)");
ok(Core.DEFAULT_BUNDLE.surface === "#000000", "writer seed surface stays black (two palettes by design)");
eq(Ingest.DEFAULT_METADATA, { name: "OLED Pure Black", source: "preset", applied: "", oledClamp: true, matugenEnabled: false },
   "metadata defaults");

// ── withToken ───────────────────────────────────────────────────────────────
var c1 = { a: "#000000", b: "#111111" };
var c2 = Ingest.withToken(c1, "b", "#222222");
ok(c2 !== c1, "withToken returns a new object");
ok(c2.a === "#000000" && c2.b === "#222222", "withToken preserves siblings, swaps the key");
ok(c1.b === "#111111", "input never mutated (reassign is the QML notify)");

// ── mapMetadata ─────────────────────────────────────────────────────────────
var cur = Object.assign({}, Ingest.DEFAULT_METADATA);
var m1 = Ingest.mapMetadata({ name: "Nord-ish", mode: "matugen" }, cur);
ok(m1.name === "Nord-ish", "name from payload");
ok(m1.source === "matugen", "legacy mode → source when source absent");
ok(m1.oledClamp === true && m1.matugenEnabled === false, "flags preserved when payload omits them");
ok(cur.name === "OLED Pure Black" && cur.source === "preset", "current metadata never mutated");
var m2 = Ingest.mapMetadata({ applied: "2026-10-29T00:00:00Z", oledClamp: false, matugenEnabled: true }, cur);
ok(m2.applied === "2026-10-29T00:00:00Z" && m2.oledClamp === false && m2.matugenEnabled === true,
   "explicit payload values win over current");

// ── mapPayload ──────────────────────────────────────────────────────────────
var p1 = Ingest.mapPayload({ colors: { background: "#010101" }, metadata: { name: "X" } },
                           Ingest.DEFAULT_COLORS, Ingest.DEFAULT_METADATA);
ok(p1.colors !== null && p1.metadata !== null, "full payload maps both halves");
ok(p1.colors.background === "#010101", "given token wins");
ok(p1.colors.text === "#e0e0e0", "missing tokens fall back to current");
ok(p1.metadata.name === "X" && p1.metadata.applied === "", "metadata half falls back too");

var p2 = Ingest.mapPayload({ colors: { surfaceVariant: "#0f0f0f" } }, Ingest.DEFAULT_COLORS, Ingest.DEFAULT_METADATA);
ok(p2.metadata === null, "metadata absent → null half");
ok(p2.colors.surfaceContainer === "#0f0f0f", "surfaceContainer cascades from surfaceVariant (legacy)");

var p3 = Ingest.mapPayload({ metadata: { name: "Only Meta" } }, Ingest.DEFAULT_COLORS, Ingest.DEFAULT_METADATA);
ok(p3.colors === null && p3.metadata.name === "Only Meta", "colors absent → null half");

eq(Ingest.mapPayload(null, Ingest.DEFAULT_COLORS, Ingest.DEFAULT_METADATA), { colors: null, metadata: null }, "null payload → both halves null");
eq(Ingest.mapPayload("junk", Ingest.DEFAULT_COLORS, Ingest.DEFAULT_METADATA), { colors: null, metadata: null }, "non-object payload → null");

// Invalid tokens fall back (normalizeBundle validates the "#" prefix — the
// writer's own rule, so intake can never disagree with write).
var p4 = Ingest.mapPayload({ colors: { background: "red", text: 42 } }, Ingest.DEFAULT_COLORS, Ingest.DEFAULT_METADATA);
ok(p4.colors.background === "#000000" && p4.colors.text === "#e0e0e0", "non-# tokens fall back to current");

// ── parseIngest ─────────────────────────────────────────────────────────────
var raw1 = JSON.stringify({ colors: { background: "#010101" }, metadata: { name: "X", applied: "t1" } });
var h1 = Ingest.parseIngest(raw1, "");
ok(h1 !== null && h1.applied === "t1" && h1.data.metadata.name === "X", "valid raw parses, applied extracted");
ok(Ingest.parseIngest(raw1, raw1) === null, "byte-identical re-read dedupes (nudge vs poll)");
ok(Ingest.parseIngest("", "") === null && Ingest.parseIngest(null, "") === null, "empty raw ignored");
ok(Ingest.parseIngest("   \n  ", "") === null, "whitespace raw ignored");
ok(Ingest.parseIngest("{oops", "") === null, "mid-write parse error → silent retry");
ok(Ingest.parseIngest("42", "") === null, "non-object JSON ignored");
var h2 = Ingest.parseIngest(JSON.stringify({ colors: {} }), "");
ok(h2 !== null && h2.applied === "", "applied absent → empty string");

if (failed) { console.error("theme-ingest.test: " + failed + " FAILURES"); process.exit(1); }
console.log("theme-ingest.test: OK");
