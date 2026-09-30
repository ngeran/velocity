// =============================================================================
// SearchIndex.qml — settings search registry (rows self-register)
// =============================================================================
// The settings dashboard has no central search manifest to keep in sync: every
// searchable ROW registers ITSELF here at creation (Component.onCompleted in
// the shared row components) and unregisters on destruction. A row appears in
// search the moment it exists — reorganizing panes or adding rows needs no
// index edits, which is the whole point of the shape.
//
//   entry = { title, tab, section, keywords, item }
//     title     row label ("LOCK AFTER")
//     tab       nav key: "settings" | "control" | "core"
//     section   sub-nav key within that tab ("" = tab-level)
//     keywords  extra match terms (hyprctl key paths, synonyms)
//     item      the row Item (highlight target; null for section-level rows)
//
// Consumers: the palette in ModernDashboard (input + results) and the
// "search" IPC target in shell.qml (scripting/truth probes).
// =============================================================================

pragma Singleton

import QtQuick

Item {
    id: root

    // Registry — plain array; reassignments are fine at ~30-entry scale.
    property var entries: []

    // Emitted when the user picks a result; ModernDashboard performs the
    // navigation (tab switch + sub-section + highlight flash) — this service
    // stays UI-free.
    signal activated(var entry)

    function register(entry) {
        // Keyed entries (section-level rows with no Item) dedupe on the key —
        // a Loader-gated tab re-registering on every open replaces its old
        // entries instead of accumulating. Item entries dedupe on the item.
        if (entry.key !== undefined && entry.key !== null && entry.key !== "")
            root.entries = root.entries.filter(function(e) { return e.key !== entry.key })
        else
            unregister(entry.item)
        root.entries = root.entries.concat([entry])
    }

    function unregister(item) {
        if (item === undefined || item === null) return
        root.entries = root.entries.filter(function(e) { return e.item !== item })
    }

    // Ranked matches: title-prefix beats title-substring beats keyword/section.
    // Empty query → no results (the palette shows nothing until you type).
    function search(query) {
        var t = String(query || "").trim().toLowerCase()
        if (t === "") return []
        var scored = []
        for (var i = 0; i < root.entries.length; i++) {
            var e = root.entries[i]
            var title = String(e.title).toLowerCase()
            var hay = (title + " " + String(e.section) + " " + String(e.keywords || "")).toLowerCase()
            var score = -1
            if (title.indexOf(t) === 0)        score = 0
            else if (title.indexOf(t) !== -1)  score = 1
            else if (hay.indexOf(t) !== -1)    score = 2
            if (score >= 0) scored.push({ entry: e, score: score })
        }
        scored.sort(function(a, b) {
            if (a.score !== b.score) return a.score - b.score
            return String(a.entry.title).localeCompare(String(b.entry.title))
        })
        return scored.map(function(s) { return s.entry })
    }

    function activate(entry) { root.activated(entry) }
}
