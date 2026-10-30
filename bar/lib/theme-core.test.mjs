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

// ── capLuminance (P5.2) ─────────────────────────────────────────────────────
ok(Core.capLuminance("#101010", 0.03) === "#101010", "capLuminance: under cap → untouched");
ok(Core.capLuminance("nonsense", 0.03) === "nonsense", "capLuminance: unparseable → untouched");
ok(Core.capLuminance("#000000", 0.5) === "#000000", "capLuminance: black stays black");
ok(near(Core.luminance(Core.capLuminance("#ffffff", 0.70)), 0.70, 0.005), "capLuminance: white → lum 0.70");
ok(Core.luminance(Core.capLuminance("#ff79c6", 0.45)) <= 0.455, "capLuminance: pink capped ≤ 0.45");
ok(Core.capLuminance("#808080", 0.45) === "#808080", "capLuminance: gray 0.216 under 0.45 → untouched");
// hue preserved: gray capped to a dimmer gray keeps its channels equal
var cappedGray = Core.capLuminance("#aaaaaa", 0.10);
ok(cappedGray[1] === cappedGray[3] && cappedGray[1] === cappedGray[5],
   "capLuminance: gray stays gray (hue kept)");

// ── clampOLED v2 ────────────────────────────────────────────────────────────
var c1 = Core.clampOLED(Core.normalizeBundle({ background: "#ffffff", surface: "#eeeeee" }, Core.DEFAULT_BUNDLE), false, Core.DEFAULT_BUNDLE);
ok(c1.background === "#ffffff", "clamp=false leaves bundle alone");
var c2 = Core.clampOLED(Core.normalizeBundle({ background: "#ffffff", surface: "#eeeeee", text: "#111111" }, Core.DEFAULT_BUNDLE), true, Core.DEFAULT_BUNDLE);
ok(c2.background === "#000000" && c2.surface === "#000000"
   && c2.surfaceVariant === "#000000" && c2.surfaceContainer === "#000000", "clamp zeroes the 4 surface tokens");
ok(Core.luminance(c2.text) >= 0.18 && Core.luminance(c2.text) <= 0.705, "too-dim text rescued to DEFAULT, then capped into the band");
var c3 = Core.clampOLED(Core.normalizeBundle({ text: "#ffffff", textDim: "#bbbbbb" }, Core.DEFAULT_BUNDLE), true, Core.DEFAULT_BUNDLE);
ok(Core.luminance(c3.text) <= 0.705 && Core.luminance(c3.text) >= 0.5, "bright text capped to ≤ 0.70, still legible");
ok(Core.luminance(c3.textDim) <= 0.255, "bright textDim capped to ≤ 0.25");
ok(c3.textDim !== "#bbbbbb", "0.48-lum textDim is above the 0.25 cap → capped");
ok(c2.accent !== undefined && c2.warning !== undefined, "clamp keeps the accent tier");

// P5.2 acceptance: the five named presets must leave the clamp with EVERY
// capped tier inside its ceiling. Inputs mirror settings/config/ThemePresets.qml
// (QML singletons aren't importable from node).
var PRESETS = {
    "Catppuccin Mocha": { background:"#1e1e2e", surface:"#181825", surfaceVariant:"#313244", surfaceContainer:"#313244", text:"#cdd6f4", textDim:"#a6adc8", border:"#313244", outline:"#45475a", outlineVariant:"#181825", primary:"#cba6f7", secondary:"#89b4fa", accent:"#f5c2e7", success:"#a6e3a1", warning:"#f9e2af", error:"#f38ba8", info:"#89dceb" },
    "Tokyo Night":      { background:"#1a1b26", surface:"#16161e", surfaceVariant:"#2f3549", surfaceContainer:"#2f3549", text:"#c0caf5", textDim:"#a9b1d6", border:"#292e42", outline:"#414868", outlineVariant:"#16161e", primary:"#7aa2f7", secondary:"#bb9af7", accent:"#e0af68", success:"#9ece6a", warning:"#e0af68", error:"#f7768e", info:"#7dcfff" },
    "Nord":             { background:"#2e3440", surface:"#2e3440", surfaceVariant:"#3b4252", surfaceContainer:"#3b4252", text:"#eceff4", textDim:"#d8dee9", border:"#3b4252", outline:"#434c5e", outlineVariant:"#2e3440", primary:"#88c0d0", secondary:"#81a1c1", accent:"#bf616a", success:"#a3be8c", warning:"#ebcb8b", error:"#bf616a", info:"#8fbcbb" },
    "Gruvbox Dark":     { background:"#282828", surface:"#1d2021", surfaceVariant:"#3c3836", surfaceContainer:"#3c3836", text:"#ebdbb2", textDim:"#d5c4a1", border:"#3c3836", outline:"#504945", outlineVariant:"#1d2021", primary:"#fabd2f", secondary:"#83a598", accent:"#fe8019", success:"#b8bb26", warning:"#fabd2f", error:"#fb4934", info:"#8ec07c" },
    "Dracula":          { background:"#282a36", surface:"#21222c", surfaceVariant:"#44475a", surfaceContainer:"#44475a", text:"#f8f8f2", textDim:"#6272a4", border:"#44475a", outline:"#6272a4", outlineVariant:"#21222c", primary:"#bd93f9", secondary:"#8be9fd", accent:"#ff79c6", success:"#50fa7b", warning:"#f1fa8c", error:"#ff5555", info:"#8be9fd" }
};
// Hue preservation: LINEAR-light channel ratios (vs the brightest channel)
// survive the cap within 1.5% — the cap scales all linear channels by one
// factor, so those ratios are the invariant. (sRGB ratios drift under gamma.)
function srgbToLin(v) {
    return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
}
function hueKept(orig, capped) {
    var a = [0, 1, 2].map(i => srgbToLin(parseInt(orig.replace("#","").substring(i*2, i*2+2), 16) / 255));
    var b = [0, 1, 2].map(i => srgbToLin(parseInt(capped.replace("#","").substring(i*2, i*2+2), 16) / 255));
    var maxA = Math.max.apply(null, a), maxB = Math.max.apply(null, b);
    if (maxA === 0 || maxB === 0) return true;
    for (var i = 0; i < 3; i++) {
        var ra = a[i] / maxA, rb = b[i] / maxB;
        if (Math.abs(ra - rb) > 0.015 * Math.max(0.02, ra)) return false;
    }
    return true;
}
for (var name in PRESETS) {
    var out = Core.clampOLED(Core.normalizeBundle(PRESETS[name], Core.DEFAULT_BUNDLE), true, Core.DEFAULT_BUNDLE);
    ok(out.background === "#000000" && out.surface === "#000000"
       && out.surfaceVariant === "#000000" && out.surfaceContainer === "#000000",
       name + ": surfaces pure black");
    ok(["border","outline","outlineVariant"].every(k => Core.luminance(out[k]) <= 0.035),
       name + ": border tier ≤ 0.03");
    ok(["primary","secondary","accent"].every(k => Core.luminance(out[k]) <= 0.455),
       name + ": accent tier ≤ 0.45");
    ok(Core.luminance(out.text) <= 0.705 && Core.luminance(out.text) >= 0.18, name + ": text in band");
    ok(Core.luminance(out.textDim) <= 0.255 && Core.luminance(out.textDim) >= 0.12, name + ": textDim in band");
    var hueOk = ["primary","secondary","accent","border","outline"].every(function (k) {
        return Core.luminance(PRESETS[name][k]) <= 0.455 || hueKept(PRESETS[name][k], out[k]);
    });
    ok(hueOk, name + ": capped tokens keep hue");
}

process.exit(failed ? 1 : 0);
