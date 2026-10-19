// discovery.mjs — turn the registry's scan output into the plugin list
// (pure: parsing, validation, precedence). The scan script prints, per
// search dir in precedence order:
//   @DIR <source> <dir>/      followed by that plugin's manifest.json text
//   @LINK <path>              every symlink found in dirs that forbid them
import { parseManifest } from "./manifest.mjs"

export function parseScanOutput(raw) {
    const symlinks = []
    const blocks = []
    let cur = null
    for (const L of String(raw || "").split("\n")) {
        if (L.indexOf("@DIR ") === 0) {
            const rest = L.slice(5)
            const sp = rest.indexOf(" ")
            cur = { source: rest.slice(0, sp), dir: rest.slice(sp + 1).trim(), json: "" }
            blocks.push(cur)
        } else if (L.indexOf("@LINK ") === 0) {
            cur = null
            symlinks.push(L.slice(6).trim())
        } else if (cur !== null) {
            cur.json += L + "\n"
        }
    }
    return { blocks, symlinks }
}

export function invalidPlugin(block, why) {
    return {
        id: block.dir, name: block.dir.split("/").filter(Boolean).pop() || block.dir,
        version: "", description: "", author: "", kinds: [], entryPoints: {},
        commands: [], ipc: [], settings: {}, defaultSection: "right",
        apiWanted: 0, dir: block.dir, source: block.source, overrides: [],
        enabled: false, status: "invalid", error: why
    }
}

function validateBlock(block, symlinks, hostApi) {
    const r = parseManifest(block.json, { hostApi })
    if (!r.ok) return invalidPlugin(block, r.errors[0])
    const link = symlinks.find(s => s.indexOf(block.dir) === 0)
    if (link) return invalidPlugin(block, "plugin folder contains a symlink: " + link)
    return Object.assign(r.plugin, {
        dir: block.dir, source: block.source, overrides: [],
        enabled: false, status: "disabled", error: ""
    })
}

// Blocks arrive in precedence order: the first valid plugin with an id
// wins; later ones with the same id are "shadowed" and recorded on the
// winner's `overrides`.
export function resolvePlugins(blocks, symlinks, hostApi) {
    const out = []
    const winner = Object.create(null)
    for (const block of blocks) {
        const p = validateBlock(block, symlinks || [], hostApi)
        if (p.status !== "invalid") {
            if (winner[p.id] !== undefined) {
                const w = out[winner[p.id]]
                w.overrides = w.overrides.concat([p.dir])
                p.status = "shadowed"
                p.error = "overridden by " + w.dir
            } else {
                winner[p.id] = out.length
            }
        }
        out.push(p)
    }
    return out
}
