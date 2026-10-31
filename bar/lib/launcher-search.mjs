// launcher-search.mjs — ranking + selection for the native launcher
// (bar/components/LauncherOverlay.qml). Ported from ryoku's shell/utils/
// fuzzy.js (rank/score/subsequence/highlight) and launcher results.js
// (resultKey/reconcileSelection): prefix beats substring beats subsequence,
// usage frequency breaks ties, names sort last. Dual-environment: imported
// by QML (`import "../lib/launcher-search.mjs" as Launcher`) and node tests.

// ── matching ────────────────────────────────────────────────────────────────
// Fields searched, in priority order: name first (its match tier wins), then
// generic name and keywords.
function haystacks(e) {
    var parts = []
    if (e.name) parts.push(String(e.name))
    if (e.genericName) parts.push(String(e.genericName))
    if (e.keywords) for (var i = 0; i < e.keywords.length; i++) parts.push(String(e.keywords[i]))
    return parts
}

function subsequence(needle, hay) {
    var j = 0
    for (var i = 0; i < hay.length && j < needle.length; i++)
        if (hay[i] === needle[j]) j++
    return j === needle.length
}

// 0 = name starts with the query, 1 = substring somewhere, 2 = in-order
// subsequence, 99 = no match.
function score(e, q) {
    var name = (e.name || "").toLowerCase()
    if (name.indexOf(q) === 0) return 0
    var fields = haystacks(e)
    var best = 99
    for (var i = 0; i < fields.length; i++) {
        var f = fields[i].toLowerCase()
        if (f.indexOf(q) !== -1) { best = Math.min(best, 1); continue }
        if (subsequence(q, f)) best = Math.min(best, 2)
    }
    return best
}

function uses(usage, e) {
    if (!usage || !e || !e.id) return 0
    var c = usage[e.id]
    return typeof c === "number" ? c : 0
}

// Entries (plain objects with id/name[/genericName/keywords/noDisplay])
// ranked against the query; usage is the frecency {id: count} map. Empty
// query = the launch-frequency list (usage desc, then name).
export function rank(entries, query, usage) {
    usage = usage || {}
    var visible = []
    for (var i = 0; i < entries.length; i++)
        if (!entries[i].noDisplay) visible.push(entries[i])

    var q = (query || "").trim().toLowerCase()
    if (q.length === 0)
        return visible.slice().sort(function (a, b) {
            var ua = uses(usage, a)
            var ub = uses(usage, b)
            if (ua !== ub) return ub - ua
            return (a.name || "").toLowerCase().localeCompare((b.name || "").toLowerCase())
        })

    var scored = []
    for (var k = 0; k < visible.length; k++) {
        var s = score(visible[k], q)
        if (s < 99) scored.push({ e: visible[k], s: s })
    }
    scored.sort(function (a, b) {
        if (a.s !== b.s) return a.s - b.s
        var ua = uses(usage, a.e)
        var ub = uses(usage, b.e)
        if (ua !== ub) return ub - ua
        return (a.e.name || "").toLowerCase().localeCompare((b.e.name || "").toLowerCase())
    })
    return scored.map(function (x) { return x.e })
}

// Spans of `query` matched against `name` as a subsequence, for the result
// row's char highlight. Adjacent hits merge; a name that doesn't contain the
// full subsequence (or an empty query) yields no spans.
export function highlight(name, query) {
    var q = (query || "").toLowerCase()
    if (q.length === 0) return []
    var hay = String(name || "").toLowerCase()
    var hits = []
    var j = 0
    for (var i = 0; i < hay.length && j < q.length; i++)
        if (hay[i] === q[j]) { hits.push(i); j++ }
    if (j < q.length) return []
    var spans = []
    for (var k = 0; k < hits.length; k++) {
        var last = spans[spans.length - 1]
        if (last && hits[k] === last.start + last.len) last.len++
        else spans.push({ start: hits[k], len: 1 })
    }
    return spans
}

// `name` cut into [{text, hit}] segments along `spans` — the row renders one
// Text per segment (hit segments take the accent) instead of RichText, so an
// app name can never inject markup into the card.
export function segments(name, spans) {
    var s = String(name || "")
    var out = []
    var at = 0
    for (var i = 0; i < spans.length; i++) {
        var sp = spans[i]
        if (sp.start > at) out.push({ text: s.slice(at, sp.start), hit: false })
        out.push({ text: s.slice(sp.start, sp.start + sp.len), hit: true })
        at = sp.start + sp.len
    }
    if (at < s.length) out.push({ text: s.slice(at), hit: false })
    return out
}

// ── provider routing (P7 G1) ─────────────────────────────────────────────────
// The first character selects a provider: `=` calculator, `>` shell command,
// `?` web search, anything else = applications (+ open windows in the QML
// layer). Everything downstream (ranking, selection stability, highlight)
// stays provider-agnostic — rows are entries with id/name[/genericName].
export function route(query) {
    var q = String(query || "")
    if (q.indexOf("=") === 0) return { provider: "calc", arg: q.slice(1) }
    if (q.indexOf(">") === 0) return { provider: "shell", arg: q.slice(1).trim() }
    if (q.indexOf("?") === 0) return { provider: "web", arg: q.slice(1).trim() }
    return { provider: "apps", arg: q }
}

// `hyprctl -j clients` output → launcher entries: id = the Wayland address
// (the focus target), name = title (class as fallback), genericName = class.
// Malformed/empty input → [] (the launcher stays an apps-only list).
export function windowEntries(clientsJson) {
    var out = []
    var arr
    try { arr = JSON.parse(String(clientsJson || "")) } catch (e) { return out }
    if (!Array.isArray(arr)) return out
    for (var i = 0; i < arr.length; i++) {
        var c = arr[i]
        if (!c || !c.address) continue
        var title = String(c.title || "").trim()
        var klass = String(c.class || "").trim()
        out.push({
            id: c.address,
            name: title.length > 0 ? title : (klass.length > 0 ? klass : String(c.address)),
            genericName: klass
        })
    }
    return out
}

// ── selection stability ─────────────────────────────────────────────────────
// Identity key for a result row (provider is implied — apps — but the shape
// keeps the door open for prefixed providers later).
export function resultKey(providerId, id) {
    return JSON.stringify([String(providerId), String(id)])
}

// Keep the selection on the row that re-ranked into a new position; if it
// fell out of the list, hold the previous INDEX (clamped) so ↑/↓ don't jump
// under a typing user. rows = the new ranked list (needs resultKey),
// selectedKey = current selection, fallbackIndex = its previous index.
export function reconcileSelection(rows, selectedKey, fallbackIndex) {
    var source = Array.isArray(rows) ? rows : []
    var selectedIndex = -1
    for (var i = 0; i < source.length; i++)
        if (source[i] && source[i].resultKey === selectedKey) { selectedIndex = i; break }
    if (selectedIndex !== -1)
        return { key: source[selectedIndex].resultKey, index: selectedIndex }
    if (source.length === 0) return { key: "", index: -1 }

    var priorIndex = typeof fallbackIndex === "number" && fallbackIndex >= 0 ? fallbackIndex : 0
    var index = Math.min(Math.max(priorIndex, 0), source.length - 1)
    return { key: source[index].resultKey, index }
}
