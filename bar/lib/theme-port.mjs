// GENERATED from shared/theme-port.mjs by tools/sync-shared — do not edit
// theme-port.mjs — theme import/export (P5.5), pure + node-tested.
// =============================================================================
// CANONICAL: shared/theme-port.mjs (tools/sync-shared -> bar/lib +
// settings/lib). The settings ThemeService is the only QML consumer today;
// the bar copy exists because the sync pair is mechanical (check-shared
// fails on drift) and future bar-side import paths stay on the same math.
//
// Formats:
//   • JSON   — { name, colors: {16 tokens} }; the custom-themes.json entry
//              shape. Import also accepts a full colors.json payload
//              ({ colors, metadata }) — the colors half is used.
//   • base16 — the standard scheme YAML (scheme/author/base00..base0F).
//              Flat "key: value" lines only; quoted or bare hex; comments
//              and blank lines ignored. A full YAML parser is NOT attempted.
//
// Token ↔ base16 mapping (documented choices, lossless for our own exports):
//   base00 background   base08 error
//   base01 surfaceVariant   base09 accent
//   base02 surfaceContainer   base0A warning
//   base03 textDim   base0B success
//   base04 outline   base0C info
//   base05 text   base0D primary
//   base06 surface   base0E secondary
//   base07 outlineVariant   base0F border
// =============================================================================

export const BASE16_TO_TOKEN = {
    base00: "background",      base08: "error",
    base01: "surfaceVariant",  base09: "accent",
    base02: "surfaceContainer", base0A: "warning",
    base03: "textDim",         base0B: "success",
    base04: "outline",         base0C: "info",
    base05: "text",            base0D: "primary",
    base06: "surface",         base0E: "secondary",
    base07: "outlineVariant",  base0F: "border"
}

var TOKEN_TO_BASE16 = {}
for (var b in BASE16_TO_TOKEN) TOKEN_TO_BASE16[BASE16_TO_TOKEN[b]] = b

var HEX_RE = /^#[0-9a-fA-F]{6}$/

function cleanHex(v) {
    var s = String(v == null ? "" : v).trim()
    if (s.charAt(0) === '"' || s.charAt(0) === "'") s = s.substring(1)
    if (s.charAt(s.length - 1) === '"' || s.charAt(s.length - 1) === "'") s = s.substring(0, s.length - 1)
    return s.trim()
}

// ── validation ──────────────────────────────────────────────────────────────
// Every PRESENT color must be a 6-digit hex string with a known token key.
// Missing tokens are legal (the caller normalizes over the defaults — that
// completion is part of the schema); a WRONG value is not. Returns
// { ok: true, colors, invalid: [keys] } or { ok: false, error }.
export function validateBundle(raw) {
    if (!raw || typeof raw !== "object") return { ok: false, error: "not an object" }
    var colors = {}, invalid = [], seen = 0
    for (var k in raw) {
        if (k === "name" || k === "metadata" || k === "author" || k === "scheme") continue
        var v = raw[k]
        if (v === undefined || v === null || v === "") continue
        var hex = cleanHex(v)
        if (!HEX_RE.test(hex)) { invalid.push(k); continue }
        if (!(k in TOKEN_TO_BASE16)) continue   // unknown key — not schema, skip
        colors[k] = hex.toUpperCase()
        seen++
    }
    if (seen === 0) return { ok: false, error: "no valid color tokens found" }
    return { ok: true, colors: colors, invalid: invalid }
}

// ── JSON ────────────────────────────────────────────────────────────────────
export function exportJson(name, bundle) {
    var colors = {}
    for (var k in bundle) colors[k] = bundle[k]
    return JSON.stringify({ name: name || "velocity theme", colors: colors }, null, 2) + "\n"
}

// Accepts {name, colors} or colors.json's {colors, metadata}. Returns
// { ok: true, name, colors } (validated) or { ok: false, error }.
export function parseJson(text) {
    var data
    try { data = JSON.parse(String(text)) } catch (e) { return { ok: false, error: "invalid JSON: " + e } }
    if (!data || typeof data !== "object") return { ok: false, error: "JSON is not an object" }
    var colors = data.colors || data
    var v = validateBundle(colors)
    if (!v.ok) return v
    return { ok: true, name: String(data.name || "imported"), colors: v.colors, invalid: v.invalid }
}

// ── base16 YAML (flat subset) ───────────────────────────────────────────────
export function exportBase16Yaml(name, bundle) {
    var lines = ["scheme: \"" + (name || "velocity theme") + "\"", "author: velocity"]
    for (var base in BASE16_TO_TOKEN) {
        var hex = bundle[BASE16_TO_TOKEN[base]]
        if (typeof hex === "string") lines.push(base + ": \"" + hex.toUpperCase() + "\"")
    }
    return lines.join("\n") + "\n"
}

// Flat "key: value" lines. Returns { ok, name, colors, invalid } / { ok:false, error }.
export function parseBase16Yaml(text) {
    var out = { name: "imported" }
    var lines = String(text).split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i]
        var hash = line.indexOf("#")
        if (hash === 0) continue                       // whole-line comment
        if (hash > 0 && !/^#[0-9a-fA-F]{1,6}/.test(line.substring(hash))) {
            // A '#' NOT directly followed by hex chars is a YAML comment
            // ("base00: #101010  # comment") — a hex value's '#' always is.
            line = line.substring(0, hash)
        }
        line = line.trim()
        if (line.length === 0) continue
        var colon = line.indexOf(":")
        if (colon <= 0) continue
        var key = line.substring(0, colon).trim()
        var val = cleanHex(line.substring(colon + 1))
        if (key === "scheme" && val.length > 0) { out.name = val.replace(/^"|"$/g, ""); continue }
        if (key === "author") continue
        if (key in BASE16_TO_TOKEN) out[BASE16_TO_TOKEN[key]] = val
    }
    var v = validateBundle(out)
    if (!v.ok) return v
    return { ok: true, name: out.name, colors: v.colors, invalid: v.invalid }
}

// Format auto-detect for a pasted/imported blob: JSON objects start with "{".
export function parseAny(text) {
    var t = String(text).trim()
    return t.charAt(0) === "{" ? parseJson(t) : parseBase16Yaml(t)
}
