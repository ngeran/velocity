// =============================================================================
// EventsReader.qml — dashboard-side reader of the system event log
// =============================================================================
// The collector (bar/services/EventService) runs in the BAR process and
// owns events.jsonl; this settings-process singleton is the VIEW-side
// mirror: cat-polls the file and exposes a newest-first ListModel plus
// summary fields for the Core-tab EVENTS pane.
//
//   POLLING   15 s while the dashboard is open (SharedState.dashboardVisible
//             gating — Bluetooth/Audio idiom), one static-command cat
//             Process re-run per tick. Deliberately NOT FileView: the writer
//             is atomic tmp+mv, and FileView does not fire on rename (the
//             recorded bar limitation) — cat-poll is the proven pattern.
//   MODEL     Newest first, capped at maxRows (300) — UI volume, not the
//             file's 500.
//   SUMMARY   lastXidText / lastXidWhen / critCount / lastSwitchText /
//             bootCount — one pass over the file keeps them consistent
//             with the model.
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform                   // StandardPaths (house idiom)
import Quickshell.Io
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

    Component.onCompleted: catProc.running = true

    function _refresh() {
        catProc.running = true
    }

    Timer {
        interval: 15000
        repeat: true
        running: Config.SharedState.dashboardVisible  // only when the dashboard is open
        onTriggered: root._refresh()
    }

    Process {
        id: catProc
        property string buffer: ""
        command: ["cat", root.eventsPath]
        stdout: SplitParser { onRead: function(line) { catProc.buffer += line + "\n" } }
        onRunningChanged: if (!running) {
            var lines = catProc.buffer.split("\n")
            catProc.buffer = ""

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
        }
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
