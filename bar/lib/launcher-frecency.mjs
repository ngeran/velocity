// launcher-frecency.mjs — decayed frecency, learned search terms, query
// history and the favorites/hidden lists for the native launcher (oma-cast
// adaptation, Tiers 1–2). Pure state
// math only; the IO (file, writes, derived bindings) lives in
// services/LauncherFrecency.qml — repo doctrine keeps logic in lib/*.mjs with
// a sibling .test.mjs. Dual-environment: imported by QML and node tests.
//
// Frecency model (oma-cast's Frecency.js): ONE synthetic "anchor" timestamp
// per app id encodes the entire launch history. score(anchor, now) =
// max(1, exp(λ·(anchor−now)/day)) with λ = ln2/10 — a 10-day half-life — and a
// launch adds VISIT_BONUS to the CURRENT score, folded back into the anchor
// (anchor = now + ln(newScore)/λ·day). No visit lists to prune, relative
// order between launches survives, never-launched ids score 0 while anything
// ever launched floors at 1 — so the empty-query "most used" list keeps its
// old shape (used apps above never-used names).

export var DAY_MS = 86400000
export var HALF_LIFE_DAYS = 10
export var LAMBDA = Math.LN2 / HALF_LIFE_DAYS   // decay per day
export var VISIT_BONUS = 100
export var TERM_WINDOW_MS = 17 * DAY_MS         // learned terms expire after 17 days
export var TERM_CAP = 20                        // per app id
export var HISTORY_CAP = 20                     // remembered queries

// Current weight of an anchor. Non-numeric/invalid anchors score 0 (never
// launched). exp() would overflow to Infinity for an absurd far-future
// anchor; clamp at exp(709.78) ≈ DBL_MAX like oma-cast does.
export function scoreOf(anchor, now) {
    if (typeof anchor !== "number" || !isFinite(anchor) || anchor <= 0) return 0
    var x = LAMBDA * (anchor - now) / DAY_MS
    if (x > 709.78) return 1.7976931348623157e308
    return Math.max(1, Math.exp(x))
}

// Fold one visit into the anchor: the fresh anchor represents oldScore +
// VISIT_BONUS at `now`, so a first launch scores exactly VISIT_BONUS and a
// decade-idle app (floor 1) jumps to 1 + VISIT_BONUS.
export function bumpAnchor(anchor, now) {
    var s = scoreOf(anchor, now)
    return now + Math.log(s + VISIT_BONUS) / LAMBDA * DAY_MS
}

// The whole frecency map as rank()-ready {id: score} numbers, dropping junk
// entries instead of throwing (a hand-edited file must not kill the launcher).
export function scoresFromAnchors(frecency, now) {
    var out = {}
    if (!frecency) return out
    for (var id in frecency) {
        var a = frecency[id]
        if (typeof a === "number" && isFinite(a) && a > 0)
            out[id] = scoreOf(a, now)
    }
    return out
}

export function emptyState() {
    return { v: 2, frecency: {}, terms: {}, history: [], favorites: [], hidden: [] }
}

// favorites/hidden are ordered id arrays (pin order = array order; Tier 2).
// An ABSENT field means empty — no rewrite churn for pre-Tier-2 files; a
// present-but-junk list (non-strings, empty ids, dupes) is repaired in place
// with changed = true.
function parseIdList(v) {
    if (!Array.isArray(v)) return { list: null, junk: true }
    var out = []
    var junk = false
    for (var i = 0; i < v.length; i++) {
        var id = v[i]
        if (typeof id !== "string" || id.length === 0 || out.indexOf(id) !== -1) {
            junk = true
            continue
        }
        out.push(id)
    }
    return { list: out, junk: junk }
}

// Toggle an id in an ordered list (favorites/hidden): present → removed;
// absent → appended at the end, so pins keep the order they were made in.
export function toggleId(list, id) {
    var src = Array.isArray(list) ? list : []
    var out = []
    for (var i = 0; i < src.length; i++)
        if (src[i] !== id) out.push(src[i])
    if (out.length === src.length) out.push(id)
    return out
}

// Parse whatever the state file holds into a valid v2 state.
//   v2 shape (clean)      → passed through, changed = false (no rewrite)
//   v2 shape (junk mixed) → junk fields dropped, changed = true (repair)
//   legacy {id: count}    → anchors that preserve today's ordering exactly
//                           (count c ⇒ anchor = now + ln(c)/λ·day, so the
//                           score at migration time equals the old count),
//                           changed = true
//   absent / garbage      → empty state; changed only for garbage (a missing
//                           file writes nothing until the first launch)
export function loadState(parsed, now) {
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
        if (parsed === null || parsed === undefined) return { state: emptyState(), changed: false }
        return { state: emptyState(), changed: true }
    }

    if (parsed.v === 2) {
        var st = emptyState()
        var changed = false
        if (parsed.frecency && typeof parsed.frecency === "object") {
            for (var id in parsed.frecency) {
                var a = parsed.frecency[id]
                if (typeof a === "number" && isFinite(a) && a > 0) st.frecency[id] = a
                else changed = true
            }
        } else if (parsed.frecency !== undefined) changed = true
        if (parsed.terms && typeof parsed.terms === "object") {
            for (var tid in parsed.terms) {
                var src = parsed.terms[tid]
                if (!Array.isArray(src)) { changed = true; continue }
                var list = []
                for (var i = 0; i < src.length; i++) {
                    var e = src[i]
                    if (e && typeof e.t === "string" && e.t.length > 0 &&
                        typeof e.at === "number" && isFinite(e.at))
                        list.push({ t: e.t, at: e.at })
                    else changed = true
                }
                if (list.length > 0) st.terms[tid] = list
            }
        } else if (parsed.terms !== undefined) changed = true
        if (Array.isArray(parsed.history)) {
            for (var h = 0; h < parsed.history.length; h++) {
                var he = parsed.history[h]
                if (he && typeof he.q === "string" && he.q.length > 0 &&
                    typeof he.at === "number" && isFinite(he.at))
                    st.history.push({ q: he.q, at: he.at })
                else changed = true
            }
            if (st.history.length > HISTORY_CAP) {
                st.history = st.history.slice(st.history.length - HISTORY_CAP)
                changed = true
            }
        } else if (parsed.history !== undefined) changed = true
        var listKeys = ["favorites", "hidden"]
        for (var k = 0; k < listKeys.length; k++) {
            var key = listKeys[k]
            if (parsed[key] === undefined) continue          // absent = empty
            var r = parseIdList(parsed[key])
            if (r.list === null) { changed = true; continue } // junk type → []
            st[key] = r.list
            if (r.junk) changed = true
        }
        return { state: st, changed: changed }
    }

    // legacy flat {id: count}: salvage every numeric count (≥ 1 becomes an
    // anchor, 0 = never launched) and drop junk values — a hand-corrupted
    // file must not irreversibly discard the user's counts
    var legacy = {}
    var salvage = false
    for (var lid in parsed) {
        var c = parsed[lid]
        if (typeof c !== "number" || !isFinite(c)) continue
        salvage = true
        if (c >= 1) legacy[lid] = now + Math.log(c) / LAMBDA * DAY_MS
    }
    if (salvage) {
        var st2 = emptyState()
        st2.frecency = legacy
        return { state: st2, changed: true }
    }
    return { state: emptyState(), changed: true }
}

// Store the query that launched an app as a learned term on its id (the
// "type ff, pick Firefox, ff means Firefox" effect). Terms are lowercased:
// rank() compares against the lowercased query, so a mixed-case launch query
// must not store an alias that can never match again. Single characters are
// noise, not aliases; duplicates re-record fresh (move to the newest slot);
// expired and overflow entries fall off the TERM_CAP end.
export function recordTerm(state, id, term, now) {
    var t = String(term || "").trim().toLowerCase()
    if (!id || t.length < 2 || t.length > 64) return state
    var src = state.terms && Array.isArray(state.terms[id]) ? state.terms[id] : []
    var list = []
    for (var i = 0; i < src.length; i++) {
        var e = src[i]
        if (e && typeof e.t === "string" && typeof e.at === "number" &&
            now - e.at <= TERM_WINDOW_MS && e.t !== t)
            list.push({ t: e.t, at: e.at })
    }
    list.push({ t: t, at: now })
    if (list.length > TERM_CAP) list = list.slice(list.length - TERM_CAP)
    var terms = Object.assign({}, state.terms)
    terms[id] = list
    return Object.assign({}, state, { terms: terms })
}

// {id: [term, …]} with expired terms gone — the shape rank() consumes.
export function liveTerms(state, now) {
    var out = {}
    if (!state || !state.terms) return out
    for (var id in state.terms) {
        var src = state.terms[id]
        if (!Array.isArray(src)) continue
        var live = []
        for (var i = 0; i < src.length; i++) {
            var e = src[i]
            if (e && typeof e.t === "string" && now - e.at <= TERM_WINDOW_MS)
                live.push(e.t)
        }
        if (live.length > 0) out[id] = live
    }
    return out
}

// Remember a query, newest last; an exact repeat moves to the end instead of
// piling up. Empty queries never record.
export function recordHistory(state, q, now) {
    var s = String(q || "").trim()
    if (s.length === 0) return state
    var src = Array.isArray(state.history) ? state.history : []
    var kept = []
    for (var i = 0; i < src.length; i++)
        if (src[i] && typeof src[i].q === "string" && src[i].q !== s) kept.push(src[i])
    kept.push({ q: s, at: now })
    if (kept.length > HISTORY_CAP) kept = kept.slice(kept.length - HISTORY_CAP)
    return Object.assign({}, state, { history: kept })
}

function bumpFrecency(state, id, now) {
    var frecency = Object.assign({}, state.frecency)
    frecency[id] = bumpAnchor(frecency[id], now)
    return Object.assign({}, state, { frecency: frecency })
}

// One launch: fold the visit, learn the query as a term (apps only — window
// addresses are ephemeral and would pollute the term store), remember the
// query. id null/absent = history-only record (calc/shell/web launches).
export function recordLaunch(state, id, query, now) {
    var s = state
    if (id) {
        s = bumpFrecency(s, id, now)
        s = recordTerm(s, id, query, now)
    }
    s = recordHistory(s, query, now)
    return s
}
