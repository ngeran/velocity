// manifest.mjs — the ONE plugin manifest validator (pure, no I/O of its own).
// Imported by the bar host (QML ES-module import), tools/validate-plugin.sh
// and the CLI, so the load-time and offline rules can't drift.
import { validateSchema } from "./settings.mjs"
import { DEFAULT_PRIORITY } from "./fit.mjs"

export const ID_PATTERN = /^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_-]+)+$/
export const RESERVED_PREFIXES = ["omarchy."]
export const KINDS = ["bar-widget", "service", "overlay"]
export const SECTIONS = ["left", "center", "right"]
const IPC_VERB = /^[a-zA-Z][a-zA-Z0-9_]*$/

export function entryKey(kind) {
    return kind === "bar-widget" ? "barWidget" : kind
}

export function isSafeEntry(name) {
    return typeof name === "string" && name !== "" && name.indexOf("/") === -1 && name.indexOf("..") === -1
}

// validateManifest(m, { hostApi, fileExists }) →
//   { ok: true, plugin }  or  { ok: false, errors: [..] }
// hostApi: the api version the host injects (required gate).
// fileExists(name): optional — offline tools check entry files exist.
export function validateManifest(m, opts) {
    const o = opts || {}
    const errors = []
    if (!m || typeof m !== "object" || Array.isArray(m)) return { ok: false, errors: ["manifest is not an object"] }

    if (m.schemaVersion !== 1 && m.schemaVersion !== 2) errors.push("schemaVersion must be 1 or 2")

    const api = m.api === undefined ? 1 : m.api
    if (o.hostApi !== undefined && api !== o.hostApi)
        errors.push("unsupported plugin api " + api + " — this host provides api " + o.hostApi
                    + (typeof api === "number" && api > o.hostApi ? " (plugin newer than shell — update velocity)" : ""))

    if (typeof m.id !== "string" || !ID_PATTERN.test(m.id))
        errors.push("id must be namespaced like 'author.name' or 'org.group.name'")
    else if (RESERVED_PREFIXES.some(p => m.id.indexOf(p) === 0))
        errors.push("id '" + m.id.split(".")[0] + ".*' is reserved")

    if (typeof m.name !== "string" || m.name === "") errors.push("name missing")
    if (typeof m.version !== "string" && typeof m.version !== "number") errors.push("version missing")

    const kinds = Array.isArray(m.kinds) ? m.kinds : null
    if (!kinds || kinds.length === 0) errors.push("kinds missing")
    const eps = m.entryPoints && typeof m.entryPoints === "object" ? m.entryPoints : null
    if (!eps) errors.push("entryPoints missing")
    for (const kind of kinds || []) {
        if (KINDS.indexOf(kind) === -1) { errors.push("unsupported kind: " + kind); continue }
        const key = entryKey(kind)
        const entry = eps ? eps[key] : undefined
        if (!isSafeEntry(entry)) errors.push("entryPoints." + key + " must be a safe relative filename")
        else if (typeof o.fileExists === "function" && !o.fileExists(entry)) errors.push("entry point file not found: '" + entry + "'")
    }

    if (m.slot !== undefined && m.slot !== "right" && m.slot !== "center")
        errors.push("slot must be 'right' or 'center'")
    const bar = m.bar && typeof m.bar === "object" ? m.bar : {}
    if (bar.defaultSection !== undefined && SECTIONS.indexOf(bar.defaultSection) === -1)
        errors.push("bar.defaultSection must be one of " + SECTIONS.join(", "))
    if (bar.collapsePriority !== undefined
            && (typeof bar.collapsePriority !== "number" || !Number.isInteger(bar.collapsePriority)))
        errors.push("bar.collapsePriority must be an integer")

    if (m.commands !== undefined && (!Array.isArray(m.commands) || m.commands.some(c => typeof c !== "string")))
        errors.push("commands must be an array of strings")
    if (m.ipc !== undefined && (!Array.isArray(m.ipc) || m.ipc.some(v => typeof v !== "string" || !IPC_VERB.test(v))))
        errors.push("ipc must be an array of verb names")
    for (const e of validateSchema(m.settings)) errors.push(e)

    if (errors.length) return { ok: false, errors }

    const defaultSection = bar.defaultSection || m.slot || "right"
    return {
        ok: true,
        plugin: {
            id: m.id,
            name: String(m.name),
            version: String(m.version),
            description: String(m.description || ""),
            author: String(m.author || m.id.split(".")[0]),
            license: String(m.license || ""),
            schemaVersion: m.schemaVersion,
            apiWanted: api,
            kinds: kinds.slice(0),
            entryPoints: Object.assign({}, eps),
            defaultSection: defaultSection,
            collapsePriority: typeof bar.collapsePriority === "number" ? bar.collapsePriority : DEFAULT_PRIORITY,
            commands: (m.commands || []).map(String),
            ipc: (m.ipc || []).slice(0),
            settings: m.settings ? Object.assign({}, m.settings) : {}
        }
    }
}

// Parse + validate in one step; JSON errors become a validation error.
export function parseManifest(text, opts) {
    let m
    try { m = JSON.parse(text) } catch (e) { return { ok: false, errors: ["manifest is not valid JSON: " + e.message] } }
    return validateManifest(m, opts)
}
