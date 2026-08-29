// =============================================================================
// EventService.qml — persistent system-event tracker (GPU Xids, boots,
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
//             lines) via ThemeService's _atomicWrite recipe (tmp.$$ + mv;
//             cat-polling readers never see a half-written file) through a
//             dynamically-created one-shot Process. Loaded back into the
//             model at startup so the panel shows history instantly.
//             Initial seed: tools/backfill-events.sh.
//
//   MODEL     ListModel `events`, NEWEST FIRST, capped at maxEvents (500);
//             `_lines` mirrors it oldest-first for the rewrite.
//
//   ALWAYS-ON Deliberately NOT popup-gated (unlike LogService): the value
//             IS the history. Idle cost: one journalctl -f -k child + a
//             10-min readlink — negligible. A watchdog (LogService pattern)
//             heals a dead stream: missing the crash line is the one failure
//             this service exists to prevent.
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

    // StandardPaths returns a QUrl ("file:///home/nikos") in this runtime —
    // coerce to string and strip the scheme (ThemeService's homeDir idiom).
    readonly property string homeDir:
        ("" + StandardPaths.writableLocation(StandardPaths.HomeLocation))
            .replace("file://", "")
    readonly property string eventsPath: homeDir + "/.config/quickshell/events.jsonl"

    property string _lastGen: ""
    property bool _manualStop: false          // intended stream stops (LogService idiom)

    Component.onCompleted: {
        console.log("[EventService] Service loaded")
        catProc.running = true                // history into the model
        unameProc.running = true              // boot event (after kernel known)
        readlinkProc.running = true           // seed _lastGen baseline
        followProc.running = true             // live kernel stream
    }

    // =========================================================================
    // PERSISTENCE  (ThemeService's _runSh/_atomicWrite recipe, verbatim)
    // =========================================================================
    function _runSh(script, label) {
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
        p.command = ["sh", "-c", script]
        p.onExited.connect(function(code) {
            if (code !== 0)
                console.error("[EventService] " + (label || "shell") +
                              " failed (exit " + code + ")")
            p.destroy()
        })
        p.running = true
        return p
    }

    function _atomicWrite(path, content) {
        var dir = path.substring(0, path.lastIndexOf("/"))
        var safe = String(content).replace(/'/g, "'\\''")
        _runSh(
            "printf '%s' '" + safe + "' > " + path + ".tmp.$$ && mv -f " +
            path + ".tmp.$$ " + path,
            "write " + path)
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
        if (_ready) _atomicWrite(eventsPath, _lines.join("\n") + "\n")
        console.log("[EventService] " + sev + " " + type + ": " + data)
    }

    // =========================================================================
    // INGEST (live kernel stream)
    // =========================================================================
    function _ingest(line) {
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

    Process {
        id: followProc
        command: ["sh", "-c", "journalctl -f -k -o json --no-pager 2>/dev/null"]
        stdout: SplitParser { onRead: function(line) { root._ingest(line) } }
        // journalctl can die (journald restart, disk pressure) — auto-heal.
        onExited: if (!root._manualStop) followRestartTimer.restart()
    }

    // 60ms gap so a stop → start actually respawns the child (re-setting
    // `running` immediately on a not-yet-reaped Process is unreliable).
    Timer {
        id: followRestartTimer
        interval: 60
        onTriggered: {
            root._manualStop = false
            if (!followProc.running) followProc.running = true
        }
    }

    // Watchdog (LogService pattern) — 5s tick; heals a death onExited missed.
    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: if (!followProc.running && !root._manualStop)
                         followRestartTimer.restart()
    }

    // =========================================================================
    // STATIC CAPTURES  (fixed commands; re-run by setting running = true)
    // =========================================================================

    // history load — file is oldest→newest; model wants newest first
    Process {
        id: catProc
        property string buffer: ""
        command: ["cat", root.eventsPath]
        stdout: SplitParser { onRead: function(line) { catProc.buffer += line + "\n" } }
        onRunningChanged: if (!running) {
            var lines = catProc.buffer.split("\n")
            catProc.buffer = ""
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
            // event that fired during the load (boot) is persisted too.
            _ready = true
            _atomicWrite(eventsPath, _lines.join("\n") + "\n")
            console.log("[EventService] loaded " + _entries.count + " events")
        }
    }

    // kernel version → boot event
    Process {
        id: unameProc
        property string buffer: ""
        command: ["uname", "-r"]
        stdout: SplitParser { onRead: function(line) { unameProc.buffer += line } }
        onRunningChanged: if (!running) {
            var k = unameProc.buffer.trim()
            unameProc.buffer = ""
            if (k) _emit("info", "boot", "boot complete — kernel " + k)
        }
    }

    // active system generation → switch detection (10-min poll)
    Process {
        id: readlinkProc
        property string buffer: ""
        command: ["sh", "-c", "readlink /run/current-system | sed 's|.*/||'"]
        stdout: SplitParser { onRead: function(line) { readlinkProc.buffer += line } }
        onRunningChanged: if (!running) {
            var gen = readlinkProc.buffer.trim()
            readlinkProc.buffer = ""
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
        onTriggered: readlinkProc.running = true
    }
}
