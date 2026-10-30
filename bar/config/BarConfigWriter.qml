// =============================================================================
// BarConfigWriter.qml — the ONE writer of bar-config.json (P2.5)
// =============================================================================
// Sole write funnel for the bar's config file. Everything else READS
// (BarConfig ingests; the settings tree mirrors through HostBridge).
//
//   merge(changes, cb)   read-modify-write: changes are merged over the disk
//                        content, so bar-owned keys a caller doesn't model
//                        (uiScale, motionScale, …) survive every save by
//                        construction — no extras snapshot to go stale. The
//                        write is atomic (tmp+mv, ThemeService recipe) and
//                        reloads BarConfig IN-PROCESS (reloadFromDisk — the
//                        old `config reload` IPC nudge existed for the
//                        cross-process writer and is gone with it).
//
// Pre-P2.5 the writer lived in the settings process (SettingsConfigService:
// cat re-read → merge → write → `qs ipc` nudge retry loop) and the bar's old
// bar-settings overlay shelled out to it (`qs -c settings ipc call
// SettingsWindow.setBarStyle …`) — a round trip that died outright when P2.1
// merged the processes and deleted the settings unit.
//
// Callers: BarSettingsBody picks (direct, same process — Control Center BAR
// page and the settings app's pane), the SettingsWindow
// setBar* verbs via SettingsBootstrap (scripting funnel), SettingsConfigService
// (the Settings-tab reset persists the bar keys it resets).
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
import Quickshell.Io

Item {
    id: root
    visible: false

    readonly property string filePath:
        StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString().replace("file://", "")
        + "/quickshell/bar-config.json"

    // One merge at a time; a merge arriving mid-flight replaces the queued
    // one (last pick wins — the UI only ever reflects the latest values).
    property var _queuedMerge: null

    function merge(changes, cb) {
        if (readProc.running || writeProc.running) {
            root._queuedMerge = { changes: changes, cb: cb }
            return
        }
        readProc.onParsed = function (raw) { root._mergeNow(raw, changes, cb) }
        readProc.running = true
    }

    function _mergeNow(raw, changes, cb) {
        var obj = {}
        try {
            var parsed = JSON.parse(raw || "")
            if (parsed && typeof parsed === "object") obj = parsed
        } catch (e) { obj = {} }   // unparseable/missing → fresh base (old extras behavior)
        for (var k in changes) {
            if (Object.prototype.hasOwnProperty.call(changes, k))
                obj[k] = changes[k]
        }
        var json = JSON.stringify(obj, null, 2)
        writeProc.onDone = cb
        writeProc.body = json
        // Command built per-write: a static command property would keep the
        // array evaluated at creation (stale body). argv-passed so no quoting
        // ever interpolates file content.
        writeProc.command = ["sh", "-c",
                             'mkdir -p "$1" && tmp="$1/.tmp.$$" && printf \'%s\' "$2" > "$tmp" && mv -f "$tmp" "$3"',
                             "bar-config-write",
                             root.filePath.substring(0, root.filePath.lastIndexOf("/")),
                             json,
                             root.filePath]
        writeProc.running = true
    }

    // ── read leg ────────────────────────────────────────────────────────────
    Process {   // unbounded-ok: one-shot `cat` of a small local file
        id: readProc
        property var onParsed: null
        property string buffer: ""
        command: ["cat", root.filePath]
        stdout: SplitParser { onRead: function(d) { readProc.buffer += d + "\n" } }
        onStarted: buffer = ""
        onRunningChanged: {
            if (running) return
            var cb = readProc.onParsed
            readProc.onParsed = null
            // Missing/unreadable file → empty buffer → fresh base.
            if (cb) cb(readProc.buffer)
        }
    }

    // ── write leg — atomic tmp+mv (ThemeService._atomicWrite recipe; $2 body) ─
    Process {   // unbounded-ok: one-shot local write
        id: writeProc
        property string body: ""
        property var onDone: null
        command: []; running: false
        // Completion rides onExited (the exit code is the signal parameter —
        // there is no readable exitCode property on this build's Process).
        onExited: function(code) {
            var ok = code === 0
            var cb = writeProc.onDone
            writeProc.onDone = null
            if (!ok) console.log("[BarConfigWriter] write failed (exit " + code + ")")
            if (cb) cb(ok)
            var q = root._queuedMerge
            if (q) { root._queuedMerge = null; root.merge(q.changes, q.cb) }
        }
    }
}
