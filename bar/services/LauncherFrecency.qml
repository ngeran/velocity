// LauncherFrecency.qml — launch-learning store for the native launcher:
// decayed frecency anchors, learned search terms and query history (oma-cast
// adaptation, Tier 1). All math lives in lib/launcher-frecency.mjs
// (node-tested); this singleton owns only the state file and the derived
// maps the overlay's rank() consumes. State lives in the session state dir,
// next to the plugins' own settings files.
//
// FileView contract note (see ThemeConfig for the full saga): blockLoading
// makes the boot read synchronous, atomicWrites keeps crash-writes clean.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/launcher-frecency.mjs" as Frecency

Singleton {
    id: root

    readonly property string file: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/velocity/launcher-usage.json"

    // v2 state: { v, frecency: {id: anchorMs}, terms: {id: [{t, at}]},
    //             history: [{q, at}] } — loaded once (migrating the legacy
    // {id: count} shape on the spot), then written only by recordLaunch.
    property var state: Frecency.emptyState()

    // Derived, binding-friendly views of state (fresh objects on every
    // recompute so the overlay's results binding re-evaluates): usage =
    // rank()'s {id: score} map, terms = rank()'s {id: [term]} map,
    // history = newest-last query list.
    property var usage: ({})
    property var terms: ({})
    property var history: []

    function _recompute(now) {
        usage = Frecency.scoresFromAnchors(state.frecency, now)
        terms = Frecency.liveTerms(state, now)
        history = state.history
    }

    function _persist() {
        store.setText(JSON.stringify(state))
    }

    // One launch: fold the frecency visit and learn the query as a term.
    // Pass a null id for calc/shell/web/window launches — they record
    // history but must not grow anchors or terms (window addresses are
    // ephemeral and would pollute the store).
    function recordLaunch(id, query) {
        var now = Date.now()
        state = Frecency.recordLaunch(state, id, query, now)
        _persist()
        _recompute(now)
    }

    // Refresh the decayed views at open time: scores sag while the overlay
    // stays closed for days, and stale views would rank on old numbers.
    function refresh() {
        _recompute(Date.now())
    }

    FileView {
        id: store
        path: root.file
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }

    Component.onCompleted: {
        var raw = store.text()
        var parsed = null
        try {
            parsed = raw && raw.length ? JSON.parse(raw) : null
        } catch (e) {
            parsed = null   // unreadable → loadState treats it as garbage
        }
        var loaded = Frecency.loadState(parsed, Date.now())
        root.state = loaded.state
        if (loaded.changed)
            root._persist()   // migration or repair lands immediately
        root._recompute(Date.now())
    }
}
