// GENERATED from shared/theme-ingest.mjs by tools/sync-shared — do not edit
// theme-ingest.mjs — the pure core of both ThemeConfig.qml singletons (P2.7)
// =============================================================================
// CANONICAL: shared/theme-ingest.mjs (tools/sync-shared -> bar/lib + settings/lib).
// Before, bar/config/ThemeConfig.qml and settings/config/ThemeConfig.qml each
// carried their own copy of the 16-token defaults, the metadata defaults,
// updateColorToken()'s rebuild, applyTheme()'s ~40-line token mapping, and the
// raw-read parse/dedupe step — five answers per concept waiting to diverge
// (the SYNC WITH blocks in both files literally asked for this module).
//
// What stays process-specific BY DESIGN (don't "fix"):
//   • the bar clamps on ingest (read-only defense; ThemeService is the sole
//     pre-clamping writer and is invisible to the bar) — settings does NOT
//   • settings owns isUserInitiated + the 100 ms external-write race window
//   • intake plumbing (FileView/nudge/poll vs watchChanges), the cross-fade,
//     hyprland border eval — all QML/IO, per tree
//
// Pure functions only — no Qt, no I/O; node-tested (bar/lib/theme-ingest.test.mjs).
// =============================================================================

import { normalizeBundle } from "./theme-core.mjs";

// The boot palette both ThemeConfig.qml singletons start on (pre-intake).
// NOT theme-core's DEFAULT_BUNDLE: that is the WRITER's "OLED Pure Black"
// seed (surface #000000); this one keeps the historical softer surfaces and
// only lives for the instant before colors.json lands. Values were the
// duplicated object literals in both QML files — kept byte-identical.
export const DEFAULT_COLORS = {
    background:       "#000000",
    surface:          "#0a0a0a",
    surfaceVariant:   "#111111",
    surfaceContainer: "#111111",
    text:             "#e0e0e0",
    textDim:          "#808080",
    border:           "#1a1a1a",
    outline:          "#2a2a2a",
    outlineVariant:   "#1a1a1a",
    primary:          "#7c6bf0",
    secondary:        "#00dce5",
    accent:           "#f87171",
    success:          "#34d399",
    warning:          "#fbbf24",
    error:            "#f87171",
    info:             "#00dce5"
};

export const DEFAULT_METADATA = {
    name:           "OLED Pure Black",
    source:         "preset",
    applied:        "",
    oledClamp:      true,
    matugenEnabled: false
};

// updateColorToken's core: colors rebuilt + reassigned (nested var keys don't
// emit change signals on in-place edit — the reassign is what notifies QML).
// Returns a NEW object; the input is never mutated.
export function withToken(colors, key, value) {
    var next = {};
    for (var k in colors) {
        if (Object.prototype.hasOwnProperty.call(colors, k)) next[k] = colors[k];
    }
    next[key] = value;
    return next;
}

// applyTheme's metadata half: per-field fallbacks onto the current metadata;
// legacy `mode` maps onto `source`. oledClamp/matugenEnabled are preserved
// when the payload omits them (a partial payload never blanks tracking state).
export function mapMetadata(m, cur) {
    return {
        name:           m.name    || cur.name,
        source:         m.source  || (m.mode || cur.source),
        applied:        m.applied || cur.applied,
        oledClamp:      (m.oledClamp !== undefined) ? m.oledClamp : cur.oledClamp,
        matugenEnabled: (m.matugenEnabled !== undefined) ? m.matugenEnabled : cur.matugenEnabled
    };
}

// applyTheme's bulk mapping: a parsed {colors, metadata} payload + the current
// palette/metadata → the next values. Each half is null when the payload
// omits it, so callers apply exactly what arrived. Colors route through
// theme-core's normalizeBundle (the writer's own normalizer — intake and
// write can never disagree about what a valid token looks like).
export function mapPayload(data, curColors, curMeta) {
    var out = { colors: null, metadata: null };
    if (!data || typeof data !== "object") return out;
    if (data.colors)   out.colors   = normalizeBundle(data.colors, curColors);
    if (data.metadata) out.metadata = mapMetadata(data.metadata, curMeta);
    return out;
}

// One raw colors.json read → { data, applied } to apply, or null to ignore:
// empty, byte-identical to the last applied read (nudge racing the fallback
// poll must be free), unparseable (file might be mid-write — silent retry on
// the next event), or not an object. `applied` is the Tier-3 timestamp for
// the caller's lastCachedTimestamp bookkeeping ("" when absent).
export function parseIngest(raw, lastCachedData) {
    var s = (raw || "").trim();
    if (s.length === 0 || s === lastCachedData) return null;
    try {
        var data = JSON.parse(s);
        if (!data || typeof data !== "object") return null;
        return { data: data, applied: (data.metadata && data.metadata.applied) ? data.metadata.applied : "" };
    } catch (e) {
        return null;
    }
}
