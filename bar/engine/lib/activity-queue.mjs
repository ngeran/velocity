// =============================================================================
// activity-queue.mjs — live-activity arbitration for the bar (J0, pure)
// =============================================================================
// Plugins (ctx.island), the OSD and scripts (island IPC) publish transient
// live activities; exactly one renders at a time. This file owns the rules:
//
//   · one visible activity: highest priority wins, ties → most recent update
//   · ladder: osd > recording > peek > progress > timer
//   · an open panel wins (the island shows the panel, not the activity)
//   · ttlMs required unless the spec carries progress; 10-min hard cap —
//     even progress activities expire unless updated (updates renew)
//   · specs with an unknown priority degrade to "timer" (a typo must not
//     steal the OSD's rank — the safe direction is the bottom)
//
// The registry itself lives in PopupCoordinator (reassigned map → bindings
// re-evaluate); every rule here is pure and node-tested. `now` is always
// injected so tests drive the clock.
// =============================================================================

// Lower rank = wins. Order per the J0 spec.
export const PRIORITIES = { osd: 0, recording: 1, peek: 2, progress: 3, timer: 4 }
export const HARD_CAP_MS = 10 * 60 * 1000

// Validate + normalize one spec → a registry entry, or null when the spec
// is unusable (no key; no ttl and no progress). `now` (ms) anchors expiry.
export function normalize(spec, now) {
    if (!spec || typeof spec !== "object") return null
    var key = String(spec.key || "")
    if (key === "") return null
    var prio = PRIORITIES[spec.priority] !== undefined ? spec.priority : "timer"
    var progress
    if (spec.progress !== undefined && spec.progress !== null) {
        var p = Number(spec.progress)
        progress = isNaN(p) ? undefined : Math.max(0, Math.min(100, Math.round(p)))
    }
    var ttl = Number(spec.ttlMs)
    var ttlOk = isFinite(ttl) && ttl > 0
    if (!ttlOk && progress === undefined) return null
    var capped = Math.floor(ttlOk ? Math.min(ttl, HARD_CAP_MS) : HARD_CAP_MS)
    var accent = (typeof spec.accent === "string" && spec.accent.indexOf("#") === 0)
        ? spec.accent : null
    return {
        key: key,
        priority: prio,
        icon: String(spec.icon || ""),
        label: String(spec.label || ""),
        accent: accent,
        progress: progress,        // undefined = no track
        focusedOnly: !!spec.focusedOnly,
        expiresAt: Math.floor(now) + capped
    }
}

// Same key = update in place (the seq makes it win ties against itself-older).
// Returns a NEW map; the input is never mutated (QML binding identity).
export function upsert(map, act, seq) {
    var m = Object.assign({}, map)
    var e = Object.assign({}, act)
    e.seq = seq
    m[act.key] = e
    return m
}

export function remove(map, key) {
    if (map[key] === undefined) return map
    var m = Object.assign({}, map)
    delete m[key]
    return m
}

// Drop expired entries. Returns { map, changed } — changed tells the caller
// whether bindings must re-evaluate.
export function sweep(map, now) {
    var m = null
    var changed = false
    for (var k in map) {
        if (map[k].expiresAt !== null && map[k].expiresAt <= now) {
            if (m === null) m = Object.assign({}, map)
            delete m[k]
            changed = true
        }
    }
    return { map: m === null ? map : m, changed: changed }
}

// THE decision: which activity renders (or null). An open panel beats
// everything (the island presents the panel); priority asc, then latest
// update wins.
export function arbitrate(map, panelOpen) {
    if (panelOpen) return null
    var best = null
    for (var k in map) {
        var a = map[k]
        if (best === null
            || PRIORITIES[a.priority] < PRIORITIES[best.priority]
            || (PRIORITIES[a.priority] === PRIORITIES[best.priority] && a.seq > best.seq))
            best = a
    }
    return best
}
