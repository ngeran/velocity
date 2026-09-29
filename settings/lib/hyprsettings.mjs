// hyprsettings.mjs — pure logic for the DESKTOP (Hyprland) settings section.
//
// The catalog below is the single source of truth: the service batches its
// getoption reads by keyword, the UI renders one row per entry, and the
// managed Lua file renders from the store — all through this module so the
// shapes are testable outside QML (hyprsettings.test.mjs).
//
// Live apply always goes through `hyprctl eval "hl.config({...})"`. The
// keyword form is a documented dead end on a Lua config: it answers "keyword
// can't work with non-legacy parsers" on stderr while exiting 0, so a write
// would look applied and do nothing.

// type is the getoption answer shape: bool answers in a "bool" field on
// current builds and "int" on older ones; css answers as a "5 5 5 5" box;
// float needs rounding. choices drive the option pills (undefined = toggle).
export const CATALOG = [
  // Effects
  { key: "blur",            group: "Effects", label: "BLUR",             keyword: "decoration:blur:enabled",     type: "bool" },
  { key: "blurSize",        group: "Effects", label: "BLUR SIZE",        keyword: "decoration:blur:size",        type: "int", choices: [2, 4, 8, 12] },
  { key: "blurPasses",      group: "Effects", label: "BLUR PASSES",      keyword: "decoration:blur:passes",      type: "int", choices: [1, 2, 3, 5] },
  { key: "blurPopups",      group: "Effects", label: "BLUR POPUPS",      keyword: "decoration:blur:popups",      type: "bool" },
  { key: "shadows",         group: "Effects", label: "SHADOWS",          keyword: "decoration:shadow:enabled",   type: "bool" },
  // Windows
  { key: "gapsIn",          group: "Windows", label: "GAPS INNER",       keyword: "general:gaps_in",             type: "css", choices: [0, 2, 5, 8, 12] },
  { key: "gapsOut",         group: "Windows", label: "GAPS OUTER",       keyword: "general:gaps_out",            type: "css", choices: [0, 2, 5, 8, 12] },
  { key: "borderSize",      group: "Windows", label: "BORDER WIDTH",     keyword: "general:border_size",         type: "int", choices: [0, 1, 2, 3] },
  { key: "rounding",        group: "Windows", label: "ROUNDING",         keyword: "decoration:rounding",         type: "int", choices: [0, 4, 8, 16] },
  { key: "activeOpacity",   group: "Windows", label: "ACTIVE OPACITY",   keyword: "decoration:active_opacity",   type: "float", choices: [0.85, 0.9, 0.95, 1] },
  { key: "inactiveOpacity", group: "Windows", label: "INACTIVE OPACITY", keyword: "decoration:inactive_opacity", type: "float", choices: [0.7, 0.8, 0.9, 1] },
]

export function settingFor(key) {
  for (var i = 0; i < CATALOG.length; i++)
    if (CATALOG[i].key === key) return CATALOG[i]
  return null
}

// Parse one `hyprctl -j getoption` answer document into a plain value.
export function valueFromAnswer(answer, type) {
  if (!answer || typeof answer !== "object") return undefined
  if (type === "bool") {
    if ("bool" in answer) return answer.bool === true
    return (answer.int ?? 0) !== 0          // legacy builds: int only
  }
  if (type === "css")
    // Read the first side — the UI edits all four as one number, and a
    // single int writes every side anyway.
    return parseInt(String(answer.css ?? "0").split(/\s+/)[0], 10) || 0
  if (type === "float")
    return Math.round((answer.float ?? 0) * 1000) / 1000
  return answer.int ?? undefined
}

// "getoption a:b:c ; getoption d:e" — one hyprctl reads them all.
export function batchArg(keywords) {
  return keywords.map(function(k) { return "getoption " + k }).join(" ; ")
}

// Lua literal for a catalog value: booleans and numbers render bare; strings
// are JSON-quoted (close enough to Lua short strings for the values we hold,
// and this catalog has none today).
export function luaValue(value) {
  if (value === true || value === false) return value ? "true" : "false"
  if (typeof value === "number") return String(value)
  return JSON.stringify(String(value))
}

// "decoration:blur:size" + 4 -> the nested-table body, innermost last.
export function luaTable(keyword, value) {
  var parts = keyword.split(":")
  var out = luaValue(value)
  for (var i = parts.length - 1; i >= 0; i--)
    out = "{ " + parts[i] + " = " + out + " }"
  return out
}

// Fold [{keyword, value}] pairs into nested objects — two blur settings share
// one blur table instead of the later overwriting the earlier.
export function nestPairs(pairs) {
  var out = {}
  for (var i = 0; i < pairs.length; i++) {
    var parts = pairs[i].keyword.split(":")
    var node = out
    for (var j = 0; j < parts.length - 1; j++) {
      if (typeof node[parts[j]] !== "object" || node[parts[j]] === null)
        node[parts[j]] = {}
      node = node[parts[j]]
    }
    node[parts[parts.length - 1]] = pairs[i].value
  }
  return out
}

function renderNode(node, indent) {
  var lines = []
  var keys = Object.keys(node)
  for (var i = 0; i < keys.length; i++) {
    var k = keys[i], v = node[k]
    if (typeof v === "object" && v !== null)
      lines.push(indent + k + " = {\n" + renderNode(v, indent + "  ") + indent + "},")
    else
      lines.push(indent + k + " = " + luaValue(v) + ",")
  }
  return lines.join("\n") + "\n"
}

function inlineNode(node) {
  return Object.keys(node).map(function(k) {
    var v = node[k]
    return k + " = " + (typeof v === "object" && v !== null ? "{ " + inlineNode(v) + " }" : luaValue(v))
  }).join(", ")
}

// Single-line eval payload: nestPairs(...)[k] rendered as "hl.config({...})".
export function evalCall(pairs) {
  var nested = nestPairs(pairs)
  return "hl.config({ " + inlineNode(nested) + " })"
}

// The whole managed file. Overrides are walked in catalog order so re-saving
// unchanged values produces byte-identical files (diffable, cache-friendly).
export function renderManagedLua(overrides) {
  var header =
    "-- Generated by velocity (velocity-settings:managed) — do not edit by hand.\n" +
    "-- Values set from the velocity settings window; a setting you reset there\n" +
    "-- disappears from this file and your own config answers again.\n\n"
  var pairs = []
  for (var i = 0; i < CATALOG.length; i++) {
    var def = CATALOG[i]
    if (overrides[def.key] !== undefined)
      pairs.push({ keyword: def.keyword, value: overrides[def.key] })
  }
  if (pairs.length === 0) return header
  var nested = nestPairs(pairs)
  var body = Object.keys(nested).map(function(k) {
    return "hl.config({\n" + renderNode(nested[k], "  ") + "})\n"
  }).join("\n")
  return header + body
}

// Change semantics: an override marks a row changed only while it differs
// from the value found before our first write. Flipping and flipping back
// removes the override, so it reads unchanged; a key with no recorded
// original (written before tracking existed, or readback never landed)
// stays marked until reset once — nothing to compare against.
export function isChanged(overrides, originals, key) {
  if (overrides[key] === undefined) return false
  if (originals[key] === undefined) return true
  return overrides[key] !== originals[key]
}

export function changedKeys(overrides, originals) {
  var out = []
  for (var k in overrides)
    if (Object.prototype.hasOwnProperty.call(overrides, k) && isChanged(overrides, originals, k))
      out.push(k)
  return out
}

// A stored override only survives a schema change if its key still exists and
// its value is still one the UI could have produced.
export function validStore(store) {
  var overrides = {}, originals = {}
  var src = (store && typeof store === "object") ? store : {}
  var rawOv = src.overrides, rawOr = src.originals
  for (var i = 0; i < CATALOG.length; i++) {
    var def = CATALOG[i]
    var ov = rawOv ? rawOv[def.key] : undefined
    var or = rawOr ? rawOr[def.key] : undefined
    if (ov !== undefined && isValidValue(def, ov)) overrides[def.key] = ov
    if (or !== undefined && isValidValue(def, or)) originals[def.key] = or
  }
  return { overrides: overrides, originals: originals }
}

function isValidValue(def, v) {
  if (def.type === "bool") return typeof v === "boolean"
  if (typeof v !== "number") return false
  if (def.choices) return def.choices.indexOf(v) !== -1
  return true
}
