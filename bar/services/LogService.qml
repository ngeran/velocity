// =============================================================================
// LogService.qml — popup-gated system journal tail (data backbone for LogsOverlay)
// =============================================================================
// Streams the full system journal (system units + user session + kernel) as
// JSON while the LogsOverlay is open; zero background cost while it is closed
// (no process, no timer — SystemInfoService's `active` gating pattern).
//
//   COMMAND   journalctl -q -n 500 -f -o json --no-pager
//             One static process does backfill (-n 500) AND follow (-f).
//             Because -n re-emits the tail on every (re)start, every start
//             CLEARS the model — no duplicate-merge or gap logic. The command
//             is a static string: no user input is ever interpolated (all
//             filtering is client-side in LogModel.js / the overlay).
//
//   STREAM    HyprlandService pattern — persistent Process + SplitParser,
//             with a watchdog that ticks only while active && following.
//
//   RING      ListModel `entries`, newest last, capped at maxEntries (1000).
//             Severity counts are maintained incrementally (decremented on
//             front-trim) so the overlay's filter chips cost O(1) per line
//             and read as "since open" counters.
//
//   FAILURES  `_manualStop` distinguishes intended stops (close/pause/
//             refresh) from stream deaths; 3 deaths with an empty model →
//             sticky `unreadable` (the overlay shows a named error state)
//             until the next refresh/open. Restarts go through a 60ms timer —
//             re-setting `running` immediately on a not-yet-reaped Process is
//             unreliable. `followProc.running` is NEVER bound; it is driven
//             imperatively only, so manual stops aren't clobbered.
//
// Resume = refresh (fresh tail, no gap-merging). Pause keeps the entries on
// screen but stops the process. Clear empties the model while following on.
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io
import "../config" as Config
import "LogModel.js" as Model

Item {
    id: root
    visible: false

    // =========================================================================
    // PUBLIC STATE  (the overlay binds these)
    // =========================================================================
    property ListModel entries: _entries
    property bool active: false              // overlay shown
    property bool following: true            // user pause/resume
    property bool unreadable: false          // journalctl died 3x with zero rows
    readonly property int maxEntries: 1000
    property int countErr: 0                 // severity counts, since open —
    property int countWarn: 0                // incremental, exact across trims
    property int countInfo: 0
    property string hostName: ""             // seeded from the first entry

    ListModel { id: _entries }

    property bool _manualStop: false         // intended stop vs stream death
    property int _failCount: 0

    // =========================================================================
    // JOURNAL STREAM
    // =========================================================================
    Process {
        id: followProc
        command: ["sh", "-c", "journalctl -q -n 500 -f -o json --no-pager 2>/dev/null"]
        stdout: SplitParser { onRead: function(line) { root._ingest(line) } }
        onRunningChanged: {
            // A stop only counts as a failure when we wanted the stream alive.
            if (!running && root.active && root.following && !root._manualStop) {
                root._failCount++
                if (Config.DebugConfig.debugEnabled)
                    console.log("[LogService] stream exit #" + root._failCount)
                if (root._failCount >= 3 && _entries.count === 0) {
                    root.unreadable = true           // sticky until refresh/open
                } else {
                    restartTimer.restart()
                }
            }
        }
    }

    // 60ms gap so a stop → start actually respawns the child.
    Timer {
        id: restartTimer
        interval: 60
        onTriggered: {
            root._manualStop = false
            if (root.active && root.following && !root.unreadable)
                followProc.running = true
        }
    }

    // Watchdog (HyprlandService pattern) — only ticks while the popup is open.
    Timer {
        interval: 5000
        repeat: true
        running: root.active && root.following
        onTriggered: if (!followProc.running && !root._manualStop && !root.unreadable)
                         restartTimer.restart()
    }

    // =========================================================================
    // PUBLIC API  (called by LogsOverlay)
    // =========================================================================
    function open()   { root.active = true;  root.following = true; root.refresh() }
    function close()  { root.active = false; root._stop() }
    function pause()  { root.following = false; root._stop() }    // entries retained
    function resume() { root.following = true;  root.refresh() }  // fresh tail, no dupes
    function clear()  { _entries.clear(); root._resetCounts() }   // stream keeps running

    function refresh() {
        root._failCount = 0
        root.unreadable = false
        _entries.clear()
        root._resetCounts()
        root._stop()
        restartTimer.restart()
    }

    // Filter predicate pass-through so the overlay never imports the .js
    // cross-directory (every repo .js import is same-directory into a service).
    function rowMatches(severity, message, unit, sevFilter, search) {
        return Model.rowMatches(severity, message, unit, sevFilter, search)
    }

    // =========================================================================
    // INTERNALS
    // =========================================================================
    function _stop() { root._manualStop = true; followProc.running = false }
    function _resetCounts() { root.countErr = 0; root.countWarn = 0; root.countInfo = 0 }

    function _ingest(line) {
        var s = String(line || "")
        if (s.length === 0 || s.charAt(0) !== "{") return     // notices / partials
        var obj = null
        try { obj = JSON.parse(s) } catch (e) { return }
        var e = Model.parseEntry(obj)
        if (!e) return
        if (!root.hostName && obj._HOSTNAME) root.hostName = obj._HOSTNAME
        _entries.append(e)
        if (e.severity === "error") root.countErr++
        else if (e.severity === "warn") root.countWarn++
        else root.countInfo++
        if (_entries.count > root.maxEntries) {
            var sev = _entries.get(0).severity               // decrement BEFORE remove
            if (sev === "error") root.countErr--
            else if (sev === "warn") root.countWarn--
            else root.countInfo--
            _entries.remove(0)
        }
    }
}
