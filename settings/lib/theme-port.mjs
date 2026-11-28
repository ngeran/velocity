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
//   • omarchy — Omarchy's theme file colors.toml (flat `key = "#rrggbb"`
//              lines; quoted or bare hex; comments ignored). DARK THEMES
//              ONLY, by the file's own `mode` line. The file carries no
//              name — the theme is its folder — so the caller passes it.
//              Import only; there is no Omarchy export.
//   • scan   — the Omarchy themes FOLDER is read in one process: a
//              `>>> <path>` header, then that colors.toml, per theme.
//              parseOmarchyScan() lists what came back.
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
//
// Token ← Omarchy mapping (user-approved 2026-11-27; LOSSY — Omarchy has 24+
// keys and most have no slot here): selection, bright_*, orange, brown,
// blue, magenta, light/bright_foreground and the hyprland_*_border values
// are dropped. The table itself is TOKEN_TO_OMARCHY, below.
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

// Our token ← the Omarchy key it is imported from (import direction only).
// Several tokens share one source on purpose — the default seed pairs
// secondary = info and accent = error the same way. Every source key exists
// in every upstream Omarchy theme, so a dark theme maps to a complete bundle.
// The three line tokens take dark_foreground rather than a background rung:
// dark_background sits one faint step above the base (1.01-1.13:1 across the
// upstream corpus), which left borders and control edges invisible.
export const TOKEN_TO_OMARCHY = {
    background:       "darker_background",
    surface:          "dark_background",
    surfaceVariant:   "background",
    surfaceContainer: "lighter_background",
    text:             "foreground",
    textDim:          "dark_foreground",
    border:           "dark_foreground",
    outline:          "dark_foreground",
    outlineVariant:   "dark_foreground",
    primary:          "accent",
    secondary:        "cyan",
    accent:           "red",
    success:          "green",
    warning:          "yellow",
    error:            "red",
    info:             "cyan"
}

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

// ── Omarchy colors.toml (flat subset) ───────────────────────────────────────
// `key = "#rrggbb"` lines. A TOML parser is NOT attempted (same stance as
// base16): no upstream theme uses tables, arrays or multiline strings.
// A quoted value is taken verbatim — a '#' INSIDE the quotes is the colour,
// not a comment — and anything after the closing quote is ignored, so inline
// `# comments` work. Keys outside the mapping are skipped silently (they are
// not "bad tokens"). `name` is the theme's folder name: the file has none.
// Returns { ok: true, name, colors, invalid }; { ok: false, light: true,
// error } for a theme that is not dark; or { ok: false, error }.
export function parseOmarchyToml(text, name) {
    var raw = {}, mode
    var lines = String(text).split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (line.length === 0 || line.charAt(0) === "#") continue
        var eq = line.indexOf("=")
        if (eq <= 0) continue
        var key = line.substring(0, eq).trim()
        var val = line.substring(eq + 1).trim()
        var quoted = /^["']([^"']*)["']/.exec(val)
        if (quoted) val = quoted[1]
        else val = val.replace(/\s+#.*$/, "").trim()
        if (key === "mode") mode = val
        else raw[key] = val
    }
    var out = {}
    for (var token in TOKEN_TO_OMARCHY) {
        var v = raw[TOKEN_TO_OMARCHY[token]]
        if (v !== undefined) out[token] = v
    }
    var res = validateBundle(out)
    if (!res.ok) return res
    // Dark only, by the file's own declaration. Checked AFTER the tokens so
    // text that is not an Omarchy theme at all keeps the useful error.
    // No mode line leaves `mode` undefined; "mode =" is a line declaring "".
    // `light` is what the folder scan counts by, so the wording may change.
    if (mode !== "dark") {
        return { ok: false, light: true, error: "only dark themes are allowed (" +
            (mode === undefined ? "no mode line" : 'mode = "' + mode + '"') + ")" }
    }
    return { ok: true, name: name || "imported", colors: res.colors, invalid: res.invalid }
}

// The reverse of TOKEN_TO_OMARCHY: an Omarchy `colors.toml` for a theme.
// Omarchy has more keys than this engine stores, so the file is built from an
// explicit table: where several tokens import from ONE key (cyan is secondary
// AND info, red is accent AND error, dark_foreground is textDim AND the three
// line tokens) the first-named token writes it, and the keys with no token of
// their own take the nearest role. A round trip (export, then import) gives
// back exactly those first-named eleven; the file's comment says the rest is
// derived.
export function exportToml(name, bundle) {
    var b = bundle || {}
    // Omarchy key <- token (import order; see TOKEN_TO_OMARCHY).
    var fromToken = {
        accent: "primary", selection: "surfaceContainer", muted: "textDim",
        darker_background: "background", dark_background: "surface",
        background: "surfaceVariant", lighter_background: "surfaceContainer",
        foreground: "text", dark_foreground: "textDim",
        light_foreground: "text", bright_foreground: "text",
        red: "accent", yellow: "warning", orange: "warning", green: "success",
        cyan: "secondary", blue: "primary", magenta: "accent", brown: "error"
    }
    var bright = ["red", "yellow", "green", "cyan", "blue", "magenta"]
    var title = String(name || "velocity theme").replace(/[\r\n]+/g, " ")
    var lines = [
        "# " + title + " - exported from Velocity as a dark theme.",
        "# Keys this engine does not store are derived from the closest token.",
        'mode = "dark"'
    ]
    // A token that is missing or not 6-digit hex is written as black.
    function line(key, token) {
        var v = b[token]
        return key + ' = "' + (HEX_RE.test(v || "") ? v.toUpperCase() : "#000000") + '"'
    }
    for (var key in fromToken) lines.push(line(key, fromToken[key]))
    for (var i = 0; i < bright.length; i++) lines.push(line("bright_" + bright[i], fromToken[bright[i]]))
    return lines.join("\n") + "\n"
}

// Name for a path import: an Omarchy theme is named by its FOLDER
// (`…/themes/<name>/colors.toml`), not by anything in the file. "" when
// there is none to use (bare filename, "./colors.toml", "/x/../colors.toml")
// — the caller falls back to the generic name.
export function themeFolderName(path) {
    var parts = String(path || "").trim().split("/")
    var folder = parts.length > 1 ? parts[parts.length - 2] : ""
    return folder === "." || folder === ".." ? "" : folder
}

// Format auto-detect for a pasted/imported blob: JSON objects start with "{".
// Omarchy's `key = "#rrggbb"` lines are told from base16's `key: value` by
// the "="; `fallbackName` only names an Omarchy theme (its file has none).
export function parseAny(text, fallbackName) {
    var t = String(text).trim()
    if (t.charAt(0) === "{") return parseJson(t)
    return /^[A-Za-z_][A-Za-z0-9_-]*\s*=\s*["']?#/m.test(t)
        ? parseOmarchyToml(t, fallbackName) : parseBase16Yaml(t)
}

// ── Omarchy themes folder scan ───────────────────────────────────────────────
// The settings service reads every `~/.config/omarchy/themes/<name>/colors.toml`
// in ONE process: `find` prints `>>> <path>` (OMARCHY_SCAN_MARK) before each
// file, and this turns that stream into a theme list. A header is the mark
// AND a path ending in the theme file's name — `find` (called with the same
// constant) emits nothing else — so file text that starts with the mark stays
// file text, and text before the first header is not a file. A light theme is
// counted, not listed — the Theme page says so in its hint — and so is
// anything unreadable.
// Returns { themes: [{ name, path, colors }], light, invalid }, sorted by name.
export const OMARCHY_THEME_FILE = "colors.toml"
export const OMARCHY_SCAN_MARK = ">>> "

export function parseOmarchyScan(text) {
    var themes = [], light = 0, invalid = 0
    var path = "", buf = null
    var tail = "/" + OMARCHY_THEME_FILE
    var lines = String(text).split("\n")
    // One finished file -> one list entry, or one count.
    function flush() {
        if (!buf) return
        var r = parseOmarchyToml(buf.join("\n"), themeFolderName(path))
        if (r.ok) themes.push({ name: r.name, path: path, colors: r.colors })
        else if (r.light) light++
        else invalid++
    }
    for (var i = 0; i < lines.length; i++) {
        // Trailing whitespace dropped: a CR would otherwise hide a real header.
        var line = lines[i].replace(/\s+$/, "")
        if (line.indexOf(OMARCHY_SCAN_MARK) === 0 && line.slice(-tail.length) === tail) {
            flush()
            path = line.substring(OMARCHY_SCAN_MARK.length).trim()
            buf = []
        } else if (buf) {
            buf.push(line)
        }
    }
    flush()
    themes.sort(function(a, b) { return a.name < b.name ? -1 : a.name > b.name ? 1 : 0 })
    return { themes: themes, light: light, invalid: invalid }
}
