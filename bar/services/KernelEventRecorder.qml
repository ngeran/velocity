// =============================================================================
// KernelEventRecorder.qml — persistent system-event tracker (GPU Xids, boots,
// nixos-rebuild switches, filesystem errors)
// =============================================================================
// Born from the 2026-08-22 GPU incident: the evidence for "what happened
// and what changed before it" existed only in journald forensics done by
// hand at 5am. This service turns that into an append-only event log the
// dashboard can show — so "did the crash follow an update?" is a glance,
// not an archaeology dig.
//
//   SOURCE    journalctl -f -k -o json --no-pager   (kernel only, live tail)
//             Client-side pattern match — the curated few, not the firehose:
//               NVRM: Xid …          → gpu-xid    (crit)   [exact "NVRM: Xid"
//                                                          prefix — Realtek's
//                                                          NIC probe also says
//                                                          "XID 688", no match]
//               NVRM: …error/timeout/locked → gpu-nvrm (crit)
//               EXT4-fs error / I/O error  → fs-error   (crit, but NOT the
//                                                          MSI monitor's ghost
//                                                          "dev sda" spam)
//   SWITCHES  10-min timer restarts readlinkProc; a changed /run/current-
//             system target (basename embeds the nixpkgs version) → event.
//   BOOT      one event at service start (info, with `uname -r`).
//
//   STORAGE   <repo>/events.jsonl — rewritten whole (≤ maxEvents short
//             lines), COALESCED (T3.1): _emit only sets `_dirty` and arms a
//             1500 ms one-shot, so a burst of N events ⇒ ONE write. The
//             write goes through eventsFile (FileView) — atomicWrites
//             defaults to true (tmp file + rename in the same dir, C++
//             side), so cat-polling readers never see a half file and the
//             burst costs ZERO processes. Loaded back into the model at
//             startup so the panel shows history instantly. Initial seed:
//             tools/backfill-events.sh. NotificationService persists its
//             own store through `_atomicWrite` below — the ONE declared
//             BoundedProcess tmp+mv writer, latest-wins queued.
//
//   MODEL     ListModel `events`, NEWEST FIRST, capped at maxEvents (500);
//             `_lines` mirrors it oldest-first for the rewrite.
//
//   ALWAYS-ON Deliberately NOT popup-gated (unlike LogService): the value
//             IS the history. Idle cost: one journalctl -f -k child + a
//             10-min readlink — negligible. A watchdog (LogService pattern)
//             heals a dead stream through an escalating respawn ladder
//             (250 ms → 1 s → 5 s → 30 s cap, reset on the first live line,
//             T2.2): missing the crash line is the one failure this service
//             exists to prevent.
//
//   STARTUP   Construction is forced by a member dereference in shell.qml
//             (QML singletons build lazily; nothing else references this
//             until a panel binds it).
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform                   // StandardPaths (ThemeService idiom)
import Quickshell.Io
import "../config" as Config

Item {
    id: root
    visible: false

    // =========================================================================
    // PUBLIC STATE  (the dashboard panel binds these)
    // =========================================================================
    property ListModel events: _entries
    readonly property int maxEvents: 500
    property int countCrit: 0
    property int countWarn: 0
    property int countInfo: 0
    property string lastXid: "never"          // short text for cards
    property string currentSystem: ""         // generation basename (live)

    // =========================================================================
    // INTERNALS
    // =========================================================================
    ListModel { id: _entries }
    property var _lines: []                   // mirrors model, oldest first
    property bool _ready: false               // history loaded — gates writes.
                                              // Without this, the boot event
                                              // (fast uname) can beat the async
                                              // history load and its atomic
                                              // write CLOBBERS the file with a
                                              // single line. Lost a full
                                              // backfill to exactly this once.
    property bool _dirty: false               // unpersisted events pending (T3.1)

    // StandardPaths returns a QUrl ("file:///home/nikos") in this runtime —
    // coerce to string and strip the scheme (ThemeService's homeDir idiom).
    readonly property string homeDir:
        ("" + StandardPaths.writableLocation(StandardPaths.HomeLocation))
            .replace("file://", "")
    readonly property string eventsPath: homeDir + "/.config/quickshell/events.jsonl"

    property string _lastGen: ""
    property bool _manualStop: false          // intended stream stops (LogService idiom)
    property int _failCount: 0

    // Escalating respawn ladder (T2.2; local copy of LogService's small
    // helper — no cross-tree import): fail #1 retries after 250 ms, then
    // 1 s, 5 s, capped at 30 s, floored at 60 ms (a not-yet-reaped Process
    // won't reliably take a new `running`). _ingest resets it on any live
    // line — a delivered line proves the pipe, match or not.
    function _restartDelay() {
        return Math.max(60, [250, 1000, 5000, 30000][Math.min(_failCount - 1, 3)])
    }

    Component.onCompleted: {
        console.log("[KernelEventRecorder] Service loaded")
        catProc.run()                // history into the model
        unameProc.run()              // boot event (after kernel known)
        readlinkProc.run()           // seed _lastGen baseline
        followProc.running = true             // live kernel stream
    }

    // =========================================================================
    // PERSISTENCE — two write paths (T3.1):
    //   events.jsonl → eventsFile (FileView), coalesced 1500 ms, zero forks;
    //                atomicWrites defaults true (tmp + rename in-dir).
    //   _atomicWrite → ONE declared BoundedProcess running `printf > tmp.$$
    //                && mv` — NotificationService's store persists through
    //                it; latest-wins: a call while a write is in flight
    //                replaces the queued payload, and onDone flushes it.
    // =========================================================================
    BoundedProcess {   // bounded: one-shot atomic tmp+mv writer (P8.1)
        id: storeWriter
        timeoutMs: 4000
        maxBytes: 65536
        onDone: function(out, err, code) {
            if (code !== 0)
                console.error("[KernelEventRecorder] atomic write failed (exit " +
                              code + "): " + root._writePath)
            if (root._writePending) root._atomicWrite(root._writePath, root._writeData)
        }
    }
    property bool _writePending: false
    property string _writePath: ""            // in flight or queued
    property string _writeData: ""            // queued payload (latest-wins)

    function _atomicWrite(path, content) {
        if (storeWriter.running) {
            root._writePending = true
            root._writePath = path
            root._writeData = content
            return
        }
        root._writePending = false
        root._writePath = path
        var safe = String(content).replace(/'/g, "'\\''")
        storeWriter.command = ["sh", "-c",
            "printf '%s' '" + safe + "' > " + path + ".tmp.$$ && mv -f " +
            path + ".tmp.$$ " + path]
        storeWriter.run()
    }

    FileView {   // events.jsonl writer — atomicWrites defaults true (tmp+rename)
        id: eventsFile
        path: root.eventsPath
        preload: false                        // write-only here; catProc owns reads
        printErrors: false
    }

    // 1500 ms write coalescer (T3.1): a burst of N events ⇒ ONE whole-file
    // rewrite through eventsFile.
    Timer {
        id: persistTimer
        interval: 1500
        running: false
        repeat: false
        onTriggered: root._flush()
    }

    function _flush() {
        if (!root._dirty || !root._ready) return
        root._dirty = false
        eventsFile.setText(_lines.join("\n") + "\n")
    }

    function _jsonLine(ts, sev, type, data) {
        var safe = String(data).replace(/\\/g, "\\\\").replace(/"/g, '\\"')
        return '{"ts":"' + ts + '","sev":"' + sev +
               '","type":"' + type + '","data":"' + safe + '"}'
    }

    // =========================================================================
    // EVENT EMISSION
    // =========================================================================
    function _emit(sev, type, data) {
        var ts = new Date().toISOString()
        _entries.insert(0, { ts: ts, sev: sev, type: type, data: data })
        if (_entries.count > maxEvents)
            _entries.remove(_entries.count - 1)
        _lines.push(_jsonLine(ts, sev, type, data))
        if (_lines.length > maxEvents)
            _lines.shift()
        if (sev === "crit") countCrit++
        else if (sev === "warn") countWarn++
        else countInfo++
        if (type === "gpu-xid") lastXid = data.slice(0, 40)
        root._dirty = true                    // coalesced persist (T3.1)
        if (_ready) persistTimer.restart()
        console.log("[KernelEventRecorder] " + sev + " " + type + ": " + data)
    }

    // =========================================================================
    // INGEST (live kernel stream)
    // =========================================================================
    function _ingest(line) {
        if (root._failCount > 0) root._failCount = 0   // live line — ladder resets
        // Cheap substring gate before JSON.parse: every emit rule fires only
        // on NVRM / EXT4-fs / I-O error text, so a line containing none of it
        // can be skipped unparsed (kernel logs are quiet at idle, but a burst
        // — the exact moment this service exists for — must not parse per line).
        if (line.indexOf("NVRM") === -1 &&
            line.indexOf("EXT4-fs error") === -1 &&
            line.indexOf("I/O error") === -1) return
        var j
        try { j = JSON.parse(line) } catch (e) { return }
        var msg = j.MESSAGE || ""
        if (!msg) return

        if (msg.indexOf("NVRM: Xid") === 0)
            _emit("crit", "gpu-xid", msg.replace("NVRM: ", "").slice(0, 160))
        else if (msg.indexOf("NVRM:") === 0 &&
                 (/error|timeout|fall|locked/i).test(msg))
            _emit("crit", "gpu-nvrm", msg.replace("NVRM: ", "").slice(0, 160))
        else if (/EXT4-fs error|I\/O error/.test(msg) &&
                 msg.indexOf("dev sda") === -1)   // MSI monitor ghost USB
            _emit("crit", "fs-error", msg.slice(0, 160))
    }

    Process {   // unbounded-ok: long-lived kernel journal tail — ALWAYS-ON (the
                // value IS the history), one child, ladder-healed (T2.2)
        id: followProc
        command: ["sh", "-c", "journalctl -f -k -o json --no-pager 2>/dev/null"]
        stdout: SplitParser { onRead: function(line) { root._ingest(line) } }
        // journalctl can die (journald restart, disk pressure) — auto-heal
        // through the ladder; only an intended stop skips it.
        onExited: {
            if (root._manualStop) return
            root._failCount++
            followRestartTimer.interval = root._restartDelay()
            followRestartTimer.restart()
        }
    }

    // ≥60ms gap so a stop → start actually respawns the child (re-setting
    // `running` immediately on a not-yet-reaped Process is unreliable); the
    // ladder stretches it on repeated deaths.
    Timer {
        id: followRestartTimer
        interval: 60
        onTriggered: {
            root._manualStop = false
            if (!followProc.running) followProc.running = true
        }
    }

    // Watchdog (LogService pattern) — 5s tick; heals a death onExited missed.
    // Skips while a restart is already pending: restart() would reset the
    // countdown every 5 s and the 30 s rung would never fire.
    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: if (!followProc.running && !followRestartTimer.running
                             && !root._manualStop)
                         followRestartTimer.restart()
    }

    // =========================================================================
    // STATIC CAPTURES  (fixed commands; re-run by setting running = true)
    // =========================================================================

    // history load — file is oldest→newest; model wants newest first
    BoundedProcess {   // bounded: one-shot history read (P8.1)
        id: catProc
        command: ["cat", root.eventsPath]
        onDone: function (out) {
            var lines = out.split("\n")
            for (var i = lines.length - 1; i >= 0; --i) {
                var l = lines[i].trim()
                if (!l) continue
                try {
                    var j = JSON.parse(l)
                    _entries.append(j)
                    _lines.unshift(l)
                    if (j.sev === "crit") countCrit++
                    else if (j.sev === "warn") countWarn++
                    else countInfo++
                    if (j.type === "gpu-xid") lastXid = j.data.slice(0, 40)
                } catch (e) { /* skip malformed line */ }
            }
            // History is in — open the write gate and flush once so any
            // event that fired during the load (boot) is persisted too
            // (they set _dirty; the coalescer stays unarmed while !_ready).
            _ready = true
            root._flush()
            console.log("[KernelEventRecorder] loaded " + _entries.count + " events")
        }
    }

    // kernel version → boot event
    BoundedProcess {   // bounded: one-shot proc read (P8.1)
        id: unameProc
        command: ["uname", "-r"]
        onDone: function (out) {
            var k = out.trim()
            if (k) _emit("info", "boot", "boot complete — kernel " + k)
        }
    }

    // active system generation → switch detection (10-min poll)
    BoundedProcess {   // bounded: one-shot sysfs read (P8.1)
        id: readlinkProc
        command: ["sh", "-c", "readlink /run/current-system | sed 's|.*/||'"]
        onDone: function (out) {
            var gen = out.trim()
            if (!gen) return
            currentSystem = gen
            if (_lastGen === "") { _lastGen = gen; return }
            if (gen !== _lastGen) {
                _lastGen = gen
                _emit("info", "nix-switch", "system switched → " + gen)
            }
        }
    }

    Timer {
        interval: 600000                       // 10 min
        repeat: true
        running: true
        onTriggered: readlinkProc.run()
    }
}
