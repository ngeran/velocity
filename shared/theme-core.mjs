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

// The 16-token default seed ("OLED Pure Black"). Values were settings
// ThemeSchema.defaults; the schema now delegates here so there is ONE seed.
// KEEP IN SYNC note: ~/.omni-nix/modules/apps/essentials.nix seedThemeColors
// is the remaining Nix-side copy (cross-repo, cannot import this).
export const DEFAULT_BUNDLE = {
    background: "#000000", surface: "#0a0a0a", surfaceVariant: "#111111",
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

// Single OLED clamp — forces the four surface tokens to pure black and
// rescues text legibility: a source palette whose text/textDim is too dim to
// read on #000 falls back to the DEFAULT bundle's text tokens (never hardcoded
// hex — the defaults are the one answer). Mutates and returns `bundle`.
export function clampOLED(bundle, clamp, defaults) {
    if (!clamp) {
        return bundle;
    }
    bundle.background = "#000000";
    bundle.surface = "#000000";
    bundle.surfaceVariant = "#000000";
    bundle.surfaceContainer = "#000000";
    var d = defaults || DEFAULT_BUNDLE
    if (luminance(bundle.text) < 0.18)
        bundle.text = d.text;
    if (luminance(bundle.textDim) < 0.12)
        bundle.textDim = d.textDim;
    return bundle;
}
