// layout.mjs — the bar layout model (pure). plugins-state.json schema 2:
//   { "schemaVersion": 2, "enabled": { id: bool }, "layout": { left, center, right } }
// Each section is an ordered list of plugin ids. An id lives in at most one
// section. Ids of disabled or missing plugins may stay listed (they keep
// their place when re-enabled); rendering filters them out.
import { SECTIONS as MANIFEST_SECTIONS } from "./manifest.mjs"

export const SECTIONS = MANIFEST_SECTIONS

// Built-in widgets (bar/builtins/velocity.<key>) and the legacy
// bar-config.json `rightLayout` keys they replace.
export const BUILTIN_LEFT = ["velocity.logo", "velocity.workspaces"]
export const LEGACY_RIGHT_KEYS = ["network", "bluetooth", "volume", "privacy", "logs", "settings", "notifications"]
export const LEGACY_DEFAULT_RIGHT = ["plugins"].concat(LEGACY_RIGHT_KEYS)
export const BUILTIN_IDS = BUILTIN_LEFT.concat(LEGACY_RIGHT_KEYS.map(k => "velocity." + k))

export function empty() {
    return { left: [], center: [], right: [] }
}

// Any input → a well-formed layout: string ids only, first occurrence wins
// (sections scanned left → center → right).
export function normalize(layout) {
    const src = layout && typeof layout === "object" && !Array.isArray(layout) ? layout : {}
    const seen = new Set()
    const out = empty()
    for (const s of SECTIONS) {
        for (const id of Array.isArray(src[s]) ? src[s] : []) {
            if (typeof id !== "string" || id === "" || seen.has(id)) continue
            seen.add(id)
            out[s].push(id)
        }
    }
    return out
}

export function sectionOf(layout, id) {
    const l = normalize(layout)
    for (const s of SECTIONS) if (l[s].indexOf(id) !== -1) return s
    return ""
}

export function remove(layout, id) {
    const l = normalize(layout)
    for (const s of SECTIONS) l[s] = l[s].filter(x => x !== id)
    return l
}

// Put `id` into `section` at `index` (out of range / negative = append),
// taking it out of wherever it was.
export function place(layout, id, section, index) {
    if (SECTIONS.indexOf(section) === -1) throw new Error("section must be one of " + SECTIONS.join(", "))
    const l = remove(layout, id)
    const list = l[section]
    const i = Number.isInteger(index) && index >= 0 && index <= list.length ? index : list.length
    list.splice(i, 0, id)
    return l
}

// Shift `id` by `delta` within its section (clamped). Unplaced = unchanged.
export function move(layout, id, delta) {
    const l = normalize(layout)
    const s = sectionOf(l, id)
    if (s === "") return l
    const from = l[s].indexOf(id)
    const to = Math.max(0, Math.min(l[s].length - 1, from + (delta | 0)))
    l[s].splice(from, 1)
    l[s].splice(to, 0, id)
    return l
}

// Drop ids not in `knownIds` (removed from disk).
export function prune(layout, knownIds) {
    const known = new Set(knownIds)
    const l = normalize(layout)
    for (const s of SECTIONS) l[s] = l[s].filter(id => known.has(id))
    return l
}

function isBarWidget(p) {
    return p && Array.isArray(p.kinds) && p.kinds.indexOf("bar-widget") !== -1
}

// Placed if absent: appended to the plugin's defaultSection.
export function ensurePlaced(layout, plugin) {
    if (!isBarWidget(plugin) || sectionOf(layout, plugin.id) !== "") return normalize(layout)
    return place(layout, plugin.id, SECTIONS.indexOf(plugin.defaultSection) !== -1 ? plugin.defaultSection : "right")
}

// What each section renders: enabled, ready bar-widget plugins in layout
// order; eligible plugins with no place are appended to their
// defaultSection (plugin-list order), so nothing enabled is ever invisible.
export function resolve(layout, plugins) {
    const l = normalize(layout)
    const byId = Object.create(null)
    for (const p of plugins || [])
        if (isBarWidget(p) && p.enabled && p.status === "ready" && byId[p.id] === undefined) byId[p.id] = p
    const out = empty()
    const used = new Set()
    for (const s of SECTIONS)
        for (const id of l[s])
            if (byId[id]) { out[s].push(byId[id]); used.add(id) }
    for (const p of plugins || []) {
        if (byId[p.id] !== p || used.has(p.id)) continue
        used.add(p.id)
        out[SECTIONS.indexOf(p.defaultSection) !== -1 ? p.defaultSection : "right"].push(p)
    }
    return out
}

// Schema-1 state + bar-config.json → schema-2 layout.
//   rightLayout  legacy rail keys ("plugins" = every right-rail plugin);
//                not an array / no legal key → the legacy default
//   order        legacy bar-widget order (ids first, rest in list order)
//   plugins      the scanned plugin list (shadowed/invalid ignored)
// Returns { layout, disabled }: built-ins the user had dropped from the
// rail come back disabled, not silently re-added.
export function migrate({ rightLayout, order, plugins }) {
    const rank = Object.create(null)
    ;(Array.isArray(order) ? order : []).forEach((id, i) => { if (rank[id] === undefined) rank[id] = i })
    const widgets = (plugins || [])
        .filter(p => isBarWidget(p) && p.status !== "invalid" && p.status !== "shadowed" && BUILTIN_IDS.indexOf(p.id) === -1)
        .map((p, i) => ({ p, i }))
        .sort((a, b) => {
            const ra = rank[a.p.id] === undefined ? Infinity : rank[a.p.id]
            const rb = rank[b.p.id] === undefined ? Infinity : rank[b.p.id]
            return ra === rb ? a.i - b.i : ra - rb
        })
        .map(x => x.p)
    const inSection = s => widgets.filter(p => (SECTIONS.indexOf(p.defaultSection) !== -1 ? p.defaultSection : "right") === s).map(p => p.id)

    let keys = Array.isArray(rightLayout) ? rightLayout.filter(k => LEGACY_DEFAULT_RIGHT.indexOf(k) !== -1) : []
    if (keys.length === 0) keys = LEGACY_DEFAULT_RIGHT
    if (keys.indexOf("plugins") === -1) keys = ["plugins"].concat(keys)

    const right = []
    for (const k of keys) {
        if (k === "plugins") inSection("right").forEach(id => right.push(id))
        else right.push("velocity." + k)
    }
    const layout = normalize({ left: BUILTIN_LEFT.concat(inSection("left")), center: inSection("center"), right })
    const disabled = LEGACY_RIGHT_KEYS.filter(k => keys.indexOf(k) === -1).map(k => "velocity." + k)
    return { layout, disabled }
}
