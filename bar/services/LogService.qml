// GENERATED from shared/LogService.qml by tools/sync-shared — do not edit
// =============================================================================
// LogService.qml — active-gated system journal tail (CANONICAL — shared/)
// =============================================================================
// CANONICAL copy: synced to bar/services/ and settings/services/ by
// tools/sync-shared (VFS blocks cross-root imports; the roots hold
// byte-identical copies — see shared/README.md). Edit HERE, then
// `tools/sync-shared`; hand-edits to a root copy fail tools/check-shared.
// The `import "../config"` below is per-root-relative: it resolves to each
// root's own DebugConfig singleton after sync.
//
// Consumers: bar's LogsOverlay (SUPER+T overlay) and the settings app's
// LOGS tab — one service each, independent streams, never both writing
// shared state.
//
// Streams the full system journal (system units + user session + kernel) as
// JSON while a logs view is open; zero background cost while it is closed
// (no process, no timer — SystemInfoService's `active` gating pattern).
//
//   COMMAND   _journalCommand() picks the form and assigns it before every
//             start — argv elements, never a shell string (__CURSOR holds
//             ';', which is shell-hostile):
//               backfill  journalctl -q -n 500 -f -o json --no-pager
//                 initial open / refresh — every backfill start CLEARS the
//                 model, so the re-emitted tail can't duplicate rows.
//               resume    journalctl -q --after-cursor <cursor> -f …
//                 death restart (T2.1) — follows strictly after the newest
//                 ingested entry: history kept, no duplicate tail. The
//                 cursor is journalctl's own opaque __CURSOR value, so
//                 there is still no user input anywhere (all filtering is
//                 client-side in LogModel.js / the overlay).
//             (--since @<µs> was the ledger's sketch but is a trap: on this
//             host @ parses SECONDS only and is second-inclusive — it would
//             replay the whole last second. Verified live 2026-11-02.)
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
//             refresh) from stream deaths; 5 consecutive deaths → sticky
//             `unreadable` regardless of model count (the overlay shows a
//             named error state) until the next refresh/open. Restarts go
//             through an escalating ladder — 250 ms → 1 s → 5 s → 30 s cap,
//             floored at 60 ms because re-setting `running` immediately on
//             a not-yet-reaped Process is unreliable — and the ladder
//             resets on the first live line. `followProc.running` is NEVER
//             bound; it is driven imperatively only, so manual stops
//             aren't clobbered.
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
    property bool unreadable: false          // journalctl died 5× running
    readonly property int maxEntries: 1000
    property int countErr: 0                 // severity counts, since open —
    property int countWarn: 0                // incremental, exact across trims
    property int countInfo: 0
    property string hostName: ""             // seeded from the first entry

    ListModel { id: _entries }

    property bool _manualStop: false         // intended stop vs stream death
    property int _failCount: 0
    property bool _resumeNext: false         // next start resumes at the cursor
    property string _lastCursor: ""          // newest ingested entry's __CURSOR

    // =========================================================================
    // JOURNAL STREAM
    // =========================================================================
    Process {   // unbounded-ok: long-lived journal tail — popup/owner-gated, ring-buffered, backoff
        id: followProc
        stdout: SplitParser { onRead: function(line) { root._ingest(line) } }
        onRunningChanged: {
            // A stop only counts as a failure when we wanted the stream alive.
            if (!running && root.active && root.following && !root._manualStop) {
                root._failCount++
                root._resumeNext = true      // death restart resumes — no re-tail
                if (Config.DebugConfig.debugEnabled)
                    console.log("[LogService] stream exit #" + root._failCount)
                if (root._failCount >= 5) {
                    root.unreadable = true           // sticky until refresh/open
                } else {
                    restartTimer.interval = root._restartDelay()
                    restartTimer.restart()
                }
            }
        }
    }

    // Escalating respawn ladder (T2.1): fail #1 retries after 250 ms, then
    // 1 s, 5 s, capped at 30 s — a journalctl that keeps dying stops forking
    // every few ms. The ≥60 ms floor stays (a not-yet-reaped Process won't
    // reliably take a new `running`); _ingest resets the ladder on the first
    // live line.
    function _restartDelay() {
        return Math.max(60, [250, 1000, 5000, 30000][Math.min(root._failCount - 1, 3)])
    }

    // The one start path: pick backfill vs cursor-resume, then spawn.
    Timer {
        id: restartTimer
        interval: 60
        onTriggered: {
            root._manualStop = false
            if (root.active && root.following && !root.unreadable) {
                followProc.command = root._journalCommand()
                followProc.running = true
            }
        }
    }

    // Watchdog (HyprlandService pattern) — only ticks while the popup is open.
    // Skips while a restart is already pending: restart() would reset the
    // countdown every 5 s, and a 30 s ladder rung would then never fire.
    Timer {
        interval: 5000
        repeat: true
        running: root.active && root.following
        onTriggered: if (!followProc.running && !restartTimer.running
                             && !root._manualStop && !root.unreadable)
                         restartTimer.restart()
    }

    // =========================================================================
    // PUBLIC API  (called by the logs views — since P2.4 both the bar overlay
    // and the settings tab reach the ONE in-process instance, so open/close
    // take a consumer tag and the journalctl child runs while ANY tag is held.
    // A bare open()/close() still works via the default tag.)
    // =========================================================================
    property var _refs: ({})                 // consumer tag → true (reassigned)
    function open(tag) {
        var t = tag || "default"
        if (!root._refs[t]) {
            var r = Object.assign({}, root._refs); r[t] = true; root._refs = r
        }
        if (Object.keys(root._refs).length === 1) {   // first consumer starts it
            root.active = true; root.following = true; root.refresh()
        }
    }
    function close(tag) {
        var t = tag || "default"
        if (!root._refs[t]) return
        var r = Object.assign({}, root._refs); delete r[t]; root._refs = r
        if (Object.keys(root._refs).length === 0) {   // last consumer stops it
            root.active = false; root._stop()
        }
    }
    function pause()  { root.following = false; root._stop() }    // entries retained
    function resume() { root.following = true;  root.refresh() }  // fresh tail, no dupes
    function clear()  { _entries.clear(); root._resetCounts() }   // stream keeps running

    function refresh() {
        root._failCount = 0
        root._resumeNext = false               // explicit refresh = full backfill
        root.unreadable = false
        _entries.clear()
        root._resetCounts()
        root._stop()
        restartTimer.interval = 60
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
    function _journalCommand() {
        // argv elements, never a shell string: __CURSOR contains ';' and
        // would split a `sh -c` line. Cursor resume is host-verified
        // (2026-11-02, systemd 260): strictly after the newest entry — no
        // gap, no duplicate tail. Trade-off vs the old `2>/dev/null` wrap:
        // journalctl stderr (e.g. a rotated-away cursor failing to seek)
        // now lands in the bar unit's journal — rare, and debug-visible.
        if (root._resumeNext && root._lastCursor !== "")
            return ["journalctl", "-q", "--after-cursor", root._lastCursor,
                    "-f", "-o", "json", "--no-pager"]
        return ["journalctl", "-q", "-n", "500", "-f", "-o", "json", "--no-pager"]
    }

    function _stop() { root._manualStop = true; followProc.running = false }
    function _resetCounts() { root.countErr = 0; root.countWarn = 0; root.countInfo = 0 }

    function _ingest(line) {
        var s = String(line || "")
        if (s.length === 0 || s.charAt(0) !== "{") return     // notices / partials
        var obj = null
        try { obj = JSON.parse(s) } catch (e) { return }
        if (obj && typeof obj === "object") {
            if (root._failCount > 0) root._failCount = 0   // live line — ladder resets
            if (obj.__CURSOR) root._lastCursor = String(obj.__CURSOR)
        }
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
