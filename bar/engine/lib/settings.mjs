// settings.mjs — plugin settings schema (manifest `settings`): validation,
// defaults and value coercion. Pure; used by manifest.mjs, SettingsStore.qml
// and the settings UI.
//
//   "settings": {
//     "city":    { "type": "string", "default": "Athens", "label": "City" },
//     "refresh": { "type": "number", "default": 600, "min": 60, "max": 3600 },
//     "osd":     { "type": "bool",   "default": true },
//     "units":   { "type": "enum",   "default": "metric", "options": ["metric", "imperial"] },
//     "zones":   { "type": "list",   "default": ["Europe/Athens"] }
//   }
// Undeclared keys may still be stored (ad-hoc plugin state); they are
// passed through untouched.

export const TYPES = ["string", "number", "bool", "enum", "list"]
const KEY = /^[A-Za-z][A-Za-z0-9_]*$/

// coerce(spec, value) → { ok: true, value } | { ok: false, error }
export function coerce(spec, value) {
    const t = spec && spec.type
    if (t === "string") return { ok: true, value: value === null || value === undefined ? "" : String(value) }
    if (t === "number") {
        const n = typeof value === "number" ? value : Number(value)
        if (typeof value === "boolean" || value === "" || value === null || !isFinite(n)) return { ok: false, error: "not a number" }
        if (spec.min !== undefined && n < spec.min) return { ok: false, error: "below min " + spec.min }
        if (spec.max !== undefined && n > spec.max) return { ok: false, error: "above max " + spec.max }
        return { ok: true, value: n }
    }
    if (t === "bool") {
        if (value === true || value === "true") return { ok: true, value: true }
        if (value === false || value === "false") return { ok: true, value: false }
        return { ok: false, error: "not a bool" }
    }
    if (t === "enum") {
        const opts = Array.isArray(spec.options) ? spec.options : []
        return opts.indexOf(value) !== -1 ? { ok: true, value } : { ok: false, error: "not one of " + opts.join(", ") }
    }
    if (t === "list") {
        if (!Array.isArray(value) || value.some(v => typeof v !== "string")) return { ok: false, error: "not a list of strings" }
        return { ok: true, value: value.slice(0) }
    }
    return { ok: false, error: "unknown type " + t }
}

// Errors for a manifest `settings` object (empty array = valid).
export function validateSchema(schema) {
    if (schema === undefined) return []
    if (!schema || typeof schema !== "object" || Array.isArray(schema)) return ["settings must be an object of { key: { type, default } }"]
    const errors = []
    for (const key of Object.keys(schema)) {
        const spec = schema[key]
        const where = "settings." + key
        if (!KEY.test(key)) { errors.push(where + ": key must be an identifier"); continue }
        if (!spec || typeof spec !== "object") { errors.push(where + " must be an object"); continue }
        if (TYPES.indexOf(spec.type) === -1) { errors.push(where + ".type must be one of " + TYPES.join(", ")); continue }
        if (spec.type === "enum" && (!Array.isArray(spec.options) || spec.options.length === 0))
            errors.push(where + ".options must be a non-empty array")
        if (!("default" in spec)) { errors.push(where + ".default missing"); continue }
        const d = coerce(spec, spec.default)
        if (!d.ok) errors.push(where + ".default invalid: " + d.error)
    }
    return errors
}

export function defaultsFor(schema) {
    const out = {}
    for (const key of Object.keys(schema || {})) {
        const d = coerce(schema[key], schema[key].default)
        if (d.ok) out[key] = d.value
    }
    return out
}

// Defaults overlaid with stored values. A stored value that no longer
// fits its declared type falls back to the default.
export function merge(schema, stored) {
    const s = schema || {}
    const out = defaultsFor(s)
    const src = stored && typeof stored === "object" && !Array.isArray(stored) ? stored : {}
    for (const key of Object.keys(src)) {
        if (!(key in s)) { out[key] = src[key]; continue }
        const c = coerce(s[key], src[key])
        if (c.ok) out[key] = c.value
    }
    return out
}

// Keys whose values differ between two value maps (shallow, JSON-compared).
export function changedKeys(before, after) {
    const keys = new Set(Object.keys(before || {}).concat(Object.keys(after || {})))
    return [...keys].filter(k => JSON.stringify((before || {})[k]) !== JSON.stringify((after || {})[k]))
}
