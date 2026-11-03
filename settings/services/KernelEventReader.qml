// =============================================================================
// KernelEventReader.qml — dashboard-side reader of the system event log
// =============================================================================
// The collector (bar/services/KernelEventRecorder) runs in the BAR process and
// owns events.jsonl; this settings-process singleton is the VIEW-side
// mirror (same process since the settings merge): FileView-watches the file
// and exposes a newest-first ListModel plus summary fields for the Core-tab
// EVENTS pane.
//
//   POLLING   T4.4: FileView { watchChanges } + parse-on-textChanged — zero
//             forks (the 15 s cat-per-tick is gone). The recorder writes
//             through FileView.setText with atomicWrites defaulting true
//             (tmp+rename), and rename-over writes are invisible to the
//             watch on this host (proven) — so the recorder's updates ride
//             a 60 s in-process reload() fallback (still dashboardVisible-
//             gated, triggeredOnStart = fresh on every dashboard open);
//             the watch itself covers IN-PLACE external writers
//             (backfill-events.sh truncates in place). Parse skips
//             unchanged text.
//   MODEL     Newest first, capped at maxRows (300) — UI volume, not the
//             file's 500.
//   SUMMARY   lastXidText / lastXidWhen / critCount / lastSwitchText /
//             bootCount — one pass over the file keeps them consistent
//             with the model.
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform                   // StandardPaths (house idiom)
import Quickshell.Io                      // FileView (Process left in T4.4)
import "../config" as Config

Item {
    id: root
    visible: false

    // =========================================================================
    // PUBLIC STATE  (CoreEventsPane binds these)
    // =========================================================================
    property ListModel events: _entries
    readonly property int maxRows: 300
    property int critCount: 0
    property int bootCount: 0
    property int switchCount: 0
    property string lastXidText: "none recorded"
    property string lastXidWhen: ""
    property string lastSwitchText: "unknown"     // generation basename
    property string lastBootText: ""
    property bool loaded: false

    // =========================================================================
    // INTERNALS
    // =========================================================================
    ListModel { id: _entries }

    readonly property string homeDir:
        ("" + StandardPaths.writableLocation(StandardPaths.HomeLocation))
            .replace("file://", "")
    readonly property string eventsPath: homeDir + "/.config/quickshell/events.jsonl"

    Component.onCompleted: evFile.reload()

    function _refresh() {
        evFile.reload()
    }

    // Fallback poll (T4.4): the recorder's atomic (rename) writes never fire
    // the watch — this carries them. triggeredOnStart ⇒ fresh on every
    // dashboard open; 60 s worst-case staleness while open (was 15 s cat).
    Timer {
        interval: 60000
        repeat: true
        running: Config.SharedState.dashboardVisible  // only when the dashboard is open
        triggeredOnStart: true
        onTriggered: root._refresh()
    }

    // events.jsonl view — in-process reads, no per-tick process (T4.4).
    // watchChanges covers in-place writers; onFileChanged must only trigger
    // the reload (text() inside the handler reads stale — KeybindsOverlay
    // lesson), the re-parse happens in onTextChanged.
    FileView {
        id: evFile
        path: root.eventsPath
        preload: false                  // loaded on demand (onCompleted + poll)
        watchChanges: true
        printErrors: false              // absent until the first boot event
        onFileChanged: reload()
        onTextChanged: root._parse(text())
    }

    property string _lastText: ""       // parse only on real changes

    function _parse(content) {
        if (content === root._lastText) return
        root._lastText = content

        var lines = content.split("\n")

        _entries.clear()
        var crit = 0, boots = 0, switches = 0
        var xidText = "", xidTs = "", lastSwitch = "", lastBoot = ""

        // file is oldest→newest; walk forward for summaries, then build
        // the newest-first model from the same pass (unshift-equivalent
        // via insert(0, …) is O(n²) at 300 rows — collect then reverse)
        var rows = []
        for (var i = 0; i < lines.length; ++i) {
            var l = lines[i].trim()
            if (!l) continue
            var j
            try { j = JSON.parse(l) } catch (e) { continue }
            rows.push(j)
            if (j.sev === "crit") crit++
            if (j.type === "boot") { boots++; lastBoot = j.data }
            if (j.type === "nix-switch") { switches++; lastSwitch = j.data }
            if (j.type === "gpu-xid") { xidText = j.data; xidTs = j.ts }
        }
        for (var k = rows.length - 1; k >= 0 && _entries.count < maxRows; --k)
            _entries.append(rows[k])

        critCount = crit
        bootCount = boots
        switchCount = switches
        lastSwitchText = lastSwitch
        lastBootText = lastBoot
        lastXidText = xidText ? xidText.slice(0, 60) : "none recorded"
        lastXidWhen = xidTs ? root._ago(xidTs) : ""
        loaded = true
        console.log("[KernelEventReader] loaded " + _entries.count + " events")
    }

    // ISO ts → "3d ago" style short relative text (pane header stat)
    function _ago(iso) {
        var then = new Date(iso).getTime()
        if (isNaN(then)) return ""
        var s = Math.max(0, (Date.now() - then) / 1000)
        if (s < 90) return "just now"
        if (s < 5400) return Math.round(s / 60) + "m ago"
        if (s < 129600) return Math.round(s / 3600) + "h ago"
        return Math.round(s / 86400) + "d ago"
    }
}
