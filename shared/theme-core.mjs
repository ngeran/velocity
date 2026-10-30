// theme-core.mjs — pure theme logic shared by the bar and settings (DU2/DU3)
// =============================================================================
// CANONICAL: shared/theme-core.mjs (tools/sync-shared -> bar/lib + settings/lib).
// This is the ONE copy of the sRGB luminance math, the 16-token bundle
// normalizer, the OLED clamp, and the default seed palette. Before, settings'
// ThemeService held the real implementation and bar/config/ThemeConfig carried
// a fork whose text-rescue fallbacks were hardcoded — two answers waiting to
// diverge (B9 was exactly that bug class in a sibling file).
//
// Consumers:
//   • settings ThemeService        — the WRITER; every apply path routes
//     through clampOLED (sole pre-clamping writer invariant, see its header)
//   • settings ThemeSchema         — `defaults` delegates to DEFAULT_BUNDLE
//   • bar ThemeConfig              — defensive re-clamp on ingest (the bar is
//     a separate process and ThemeService is invisible to it)
//
// Pure functions only — no Qt, no I/O; node-tested (bar/lib/theme-core.test.mjs).
// =============================================================================

// The 16-token default seed — and THE "OLED Pure Black" definition (P1.9:
// settings ThemePresets derives its preset entry from here; before, two
// diverging copies existed, one with a non-black surface). Values were
// settings ThemeSchema.defaults; the schema delegates here so there is ONE
// seed. KEEP IN SYNC note: ~/.omni-nix/modules/apps/essentials.nix
// seedThemeColors is the remaining Nix-side copy (cross-repo, cannot import).
export const DEFAULT_BUNDLE = {
    background: "#000000", surface: "#000000", surfaceVariant: "#0a0a0a",
    surfaceContainer: "#111111", text: "#e0e0e0", textDim: "#808080",
    border: "#1a1a1a", outline: "#2a2a2a", outlineVariant: "#1a1a1a",
    primary: "#7c6bf0", secondary: "#00dce5", accent: "#f87171",
    success: "#34d399", warning: "#fbbf24", error: "#f87171", info: "#00dce5"
};

// Relative luminance (0..1, sRGB) of a "#rrggbb" string; invalid → 0.
export function luminance(hex) {
    var h = (hex || "#000000").replace("#", "")
    if (h.length !== 6) return 0
    var ch = function (s) {
        var v = parseInt(s, 16) / 255
        return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * ch(h.substring(0, 2)) + 0.7152 * ch(h.substring(2, 4)) + 0.0722 * ch(h.substring(4, 6))
}

// Canonical 16-token bundle from a raw/partial color object. Missing or
// non-"#"-prefixed values fall back to `defaults`; surfaceContainer cascades
// from surfaceVariant when only the variant is given (legacy palettes).
export function normalizeBundle(raw, defaults) {
    var d = defaults || DEFAULT_BUNDLE
    var has = function (k) { return raw && typeof raw[k] === "string" && raw[k].charAt(0) === "#" }
    var pick = function (k, fb) { return has(k) ? raw[k] : fb }
    return {
        background:       pick("background", d.background),
        surface:          pick("surface", d.surface),
        surfaceVariant:   pick("surfaceVariant", d.surfaceVariant),
        surfaceContainer: pick("surfaceContainer", has("surfaceVariant") ? raw.surfaceVariant : d.surfaceContainer),
        text:             pick("text", d.text),
        textDim:          pick("textDim", d.textDim),
        border:           pick("border", d.border),
        outline:          pick("outline", d.outline),
        outlineVariant:   pick("outlineVariant", d.outlineVariant),
        primary:          pick("primary", d.primary),
        secondary:        pick("secondary", d.secondary),
        accent:           pick("accent", d.accent),
        success:          pick("success", d.success),
        warning:          pick("warning", d.warning),
        error:            pick("error", d.error),
        info:             pick("info", d.info)
    }
}

// sRGB ↔ linear-light conversion (the inverse pair behind `luminance`).
// The clamp caps work in LINEAR light: scaling every channel by the same
// factor scales relative luminance by exactly that factor (it is a weighted
// linear sum), and preserves the hue — the channel RATIOS never move. Capping
// in sRGB space would overshoot (gamma curve) and shift hue.
function srgbToLin(v) {
    return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
}
function linToSrgb(v) {
    return v <= 0.0031308 ? v * 12.92 : 1.055 * Math.pow(v, 1 / 2.4) - 0.055
}

// "#rrggbb" → [r,g,b] in 0..1 (linear light); null when unparseable.
function hexToLinRgb(hex) {
    var h = (hex || "").replace("#", "")
    if (h.length !== 6 || /[^0-9a-fA-F]/.test(h)) return null
    return [
        srgbToLin(parseInt(h.substring(0, 2), 16) / 255),
        srgbToLin(parseInt(h.substring(2, 4), 16) / 255),
        srgbToLin(parseInt(h.substring(4, 6), 16) / 255)
    ]
}

// [r,g,b] in LINEAR light → "#rrggbb" (sRGB-encoded); mirrors hexToLinRgb.
function linRgbToHex(rgb) {
    var two = function (v) {
        var s = Math.round(Math.min(1, Math.max(0, linToSrgb(v))) * 255).toString(16)
        return s.length === 1 ? "0" + s : s
    }
    return "#" + two(rgb[0]) + two(rgb[1]) + two(rgb[2])
}

// Cap a color's RELATIVE luminance at `cap` (0..1), hue kept. Colors already
// at or under the cap (and unparseable strings) pass through untouched. 8-bit
// rounding can nudge the result ±0.004 — tests allow that slack.
export function capLuminance(hex, cap) {
    var rgb = hexToLinRgb(hex)
    if (!rgb) return hex
    var L = 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]
    if (L <= cap || L === 0) return hex
    var f = cap / L
    return linRgbToHex([rgb[0] * f, rgb[1] * f, rgb[2] * f])
}

// The OLED clamp (v2, P5.2) — every token tier gets a luminance ceiling, so a
// preset can never ship a burn-risk token:
//   background/surface/surfaceVariant/surfaceContainer → pure #000000
//   border/outline/outlineVariant                      → lum ≤ 0.03 (hairline)
//   primary/secondary/accent                           → lum ≤ 0.45 (ornament)
//   text                                               → lum ≤ 0.70
//   textDim                                            → lum ≤ 0.25
// Legibility rescue kept from v1 and applied BEFORE the caps: text/textDim
// too dim to read on #000 fall back to the DEFAULT bundle's tokens (never
// hardcoded hex — the defaults are the one answer); the cap then applies to
// the rescued value too (the default text at 0.734 lands a hair under the
// cap — intended: the seed must obey the same doctrine it enforces).
// Mutates and returns `bundle`.
export function clampOLED(bundle, clamp, defaults) {
    if (!clamp) {
        return bundle;
    }
    bundle.background = "#000000";
    bundle.surface = "#000000";
    bundle.surfaceVariant = "#000000";
    bundle.surfaceContainer = "#000000";
    bundle.border        = capLuminance(bundle.border, 0.03);
    bundle.outline       = capLuminance(bundle.outline, 0.03);
    bundle.outlineVariant = capLuminance(bundle.outlineVariant, 0.03);
    bundle.primary       = capLuminance(bundle.primary, 0.45);
    bundle.secondary     = capLuminance(bundle.secondary, 0.45);
    bundle.accent        = capLuminance(bundle.accent, 0.45);
    var d = defaults || DEFAULT_BUNDLE
    if (luminance(bundle.text) < 0.18)
        bundle.text = d.text;
    bundle.text = capLuminance(bundle.text, 0.70);
    if (luminance(bundle.textDim) < 0.12)
        bundle.textDim = d.textDim;
    bundle.textDim = capLuminance(bundle.textDim, 0.25);
    return bundle;
}
