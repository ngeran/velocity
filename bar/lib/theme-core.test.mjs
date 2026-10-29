// theme-core.test.mjs — node checks for shared/theme-core.mjs (DU2/DU3).
// Run: tools/run-unit-tests (auto-discovered). Plain asserts, no framework.
import * as Core from "./theme-core.mjs";

let failed = 0;
function ok(cond, name) {
    if (cond) { console.log("  ok", name); }
    else { console.error("  FAIL", name); failed++; }
}
function near(a, b, eps) { return Math.abs(a - b) <= (eps === undefined ? 1e-6 : eps); }

// ── DEFAULT_BUNDLE ──────────────────────────────────────────────────────────
ok(Core.DEFAULT_BUNDLE.text === "#e0e0e0", "seed text token");
ok(Core.DEFAULT_BUNDLE.textDim === "#808080", "seed textDim token");
ok(Object.keys(Core.DEFAULT_BUNDLE).length === 16, "16 canonical tokens");

// ── luminance ───────────────────────────────────────────────────────────────
ok(Core.luminance("#000000") === 0, "black luminance 0");
ok(near(Core.luminance("#ffffff"), 1), "white luminance 1");
ok(Core.luminance("invalid") === 0, "invalid string → 0");
ok(Core.luminance("#fff") === 0, "short hex → 0");
ok(Core.luminance(null) === 0, "null → 0");
ok(near(Core.luminance("#808080"), 0.2159, 1e-3), "mid-gray ~0.216 (sRGB curve, not linear)");

// ── normalizeBundle ─────────────────────────────────────────────────────────
var nb = Core.normalizeBundle({}, Core.DEFAULT_BUNDLE);
ok(nb.background === "#000000" && nb.text === "#e0e0e0", "empty raw → all defaults");
ok(nb.surfaceContainer === "#111111", "empty raw → container default");
var nb2 = Core.normalizeBundle({ background: "#111111", surfaceVariant: "#222222" }, Core.DEFAULT_BUNDLE);
ok(nb2.background === "#111111", "raw value wins");
ok(nb2.surfaceContainer === "#222222", "container cascades from raw surfaceVariant");
var nb3 = Core.normalizeBundle({ surface: "red" }, Core.DEFAULT_BUNDLE);
ok(nb3.surface === Core.DEFAULT_BUNDLE.surface, "non-# value rejected → default");

// ── clampOLED ───────────────────────────────────────────────────────────────
var c1 = Core.clampOLED(Core.normalizeBundle({ background: "#ffffff", surface: "#eeeeee" }, Core.DEFAULT_BUNDLE), false, Core.DEFAULT_BUNDLE);
ok(c1.background === "#ffffff", "clamp=false leaves bundle alone");
var c2 = Core.clampOLED(Core.normalizeBundle({ background: "#ffffff", surface: "#eeeeee", text: "#111111" }, Core.DEFAULT_BUNDLE), true, Core.DEFAULT_BUNDLE);
ok(c2.background === "#000000" && c2.surface === "#000000"
   && c2.surfaceVariant === "#000000" && c2.surfaceContainer === "#000000", "clamp zeroes the 4 surface tokens");
ok(c2.text === Core.DEFAULT_BUNDLE.text, "too-dim text rescued to DEFAULT (not hardcoded hex)");
var c3 = Core.clampOLED(Core.normalizeBundle({ text: "#ffffff", textDim: "#bbbbbb" }, Core.DEFAULT_BUNDLE), true, Core.DEFAULT_BUNDLE);
ok(c3.text === "#ffffff" && c3.textDim === "#bbbbbb", "legible text survives the clamp");
ok(c2.accent !== undefined && c2.warning !== undefined, "clamp keeps the accent tier");

process.exit(failed ? 1 : 0);
