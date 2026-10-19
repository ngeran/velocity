// fit.mjs — bar overflow planning (pure). A scene hands in the per-cell
// widths it measured plus each cell's collapse priority; the plan answers,
// for one window width, WHICH widgets shrink to their compact width
// (ctx.fit "compact") and WHICH hide ("collapsed"), and where the center
// section may sit so it never overlaps the rails.
//
// Collapse order: full → compact (label-bearing cells drop to `wc`) →
// hide by ascending collapsePriority (low priority hides first; manifest
// bar.collapsePriority, default 50 — workspaces 95 outlasts settings 20).
// The full stage demands `slack` px of headroom (hysteresis) so a cell at
// the boundary doesn't flap between full and compact; the compact and hide
// stages test against the raw width. Widths are the caller's numbers — this
// module never measures, imports nothing, and stays node-testable (D1).
export const DEFAULT_PRIORITY = 50

// Junk-tolerant cell reader: drops id-less/zero-width entries, clamps
// wc into [0, w] (missing wc = "not compactable"), defaults p.
function cells(v) {
    if (!Array.isArray(v)) return []
    const out = []
    for (const c of v) {
        if (!c || typeof c !== "object") continue
        const w = Math.max(0, Math.round(Number(c.w) || 0))
        if (w <= 0 || typeof c.id !== "string" || c.id === "") continue
        const wcRaw = Math.round(Number(c.wc) || 0)
        const p = Number.isFinite(Number(c.p)) ? Math.round(Number(c.p)) : DEFAULT_PRIORITY
        out.push({ id: c.id, p, w, wc: Math.max(0, Math.min(w, wcRaw > 0 ? wcRaw : w)) })
    }
    return out
}

function secWidth(list, gap, hidden, compacted) {
    let total = 0, n = 0
    for (const c of list) {
        if (hidden.has(c.id)) continue
        total += compacted.has(c.id) ? c.wc : c.w
        n++
    }
    return n > 1 ? total + gap * (n - 1) : total
}

// planFit({ width, pad, gap, slack, left, center, right }) →
//   { fits, stage, compacted, hidden, centerX, widths, maps }
//   left/center/right: arrays of { id, w, wc?, p? }; widths are the
//   effective (post-collapse) section widths; maps[section][id] is
//   "full" | "compact" | "collapsed" for the scene to apply.
export function planFit(opts) {
    const o = opts || {}
    const width = Math.max(0, Math.round(Number(o.width) || 0))
    const pad = Math.max(0, Math.round(Number(o.pad) || 0))
    const gap = Math.max(0, Math.round(Number(o.gap) || 0))
    const slack = Math.max(0, Math.round(Number(o.slack) || 0))
    const secs = { left: cells(o.left), center: cells(o.center), right: cells(o.right) }

    const widthsFor = (hidden, compacted) => ({
        left: secWidth(secs.left, gap, hidden, compacted),
        center: secWidth(secs.center, gap, hidden, compacted),
        right: secWidth(secs.right, gap, hidden, compacted),
    })
    const totalFor = w => pad * 2 + w.left + w.center + w.right

    const finish = (stage, hidden, compacted, widths) => {
        const state = id => hidden.has(id) ? "collapsed" : (compacted.has(id) ? "compact" : "full")
        const maps = {}
        for (const s of Object.keys(secs)) {
            maps[s] = {}
            for (const c of secs[s]) maps[s][c.id] = state(c.id)
        }
        // Center clamped between the rails; when the rails themselves meet
        // (lo > hi) clamp into the surviving span instead of drifting off-window.
        const ideal = (width - widths.center) / 2
        const lo = pad + widths.left + gap
        const hi = width - pad - widths.right - gap - widths.center
        const centerX = Math.round(hi >= lo
            ? Math.min(hi, Math.max(lo, ideal))
            : Math.min(Math.max(ideal, hi), lo))
        return {
            fits: totalFor(widths) <= width,
            stage,
            compacted: [...compacted],
            hidden: [...hidden],
            centerX,
            widths,
            maps,
        }
    }

    // 1 — full, with slack headroom (hysteresis against the compact edge).
    const full = new Set(), none = new Set()
    let w = widthsFor(full, none)
    if (totalFor(w) <= width - slack) return finish("full", full, none, w)

    // 2 — compact everything that can shrink.
    const compacted = new Set()
    for (const c of secs.left.concat(secs.center, secs.right))
        if (c.wc < c.w) compacted.add(c.id)
    w = widthsFor(full, compacted)
    if (totalFor(w) <= width) return finish("compact", full, compacted, w)

    // 3 — still too wide: hide by ascending priority (stable within a tie).
    const order = secs.left.concat(secs.center, secs.right).sort((a, b) => a.p - b.p)
    const hidden = new Set()
    for (const c of order) {
        hidden.add(c.id)
        w = widthsFor(hidden, compacted)
        if (totalFor(w) <= width) return finish("hide", hidden, compacted, w)
    }
    return finish("hide", hidden, compacted, w)   // degenerate: everything hidden
}
