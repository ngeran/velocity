// =============================================================================
// nikos.vnc — VncService (qmldir singleton)
// =============================================================================
// State + telemetry for VNC sessions (WireGuardService pattern):
//
//   • Pure parsing/formatting lives in lib/model.mjs (node-tested); this
//     file is only the probe/action/store wrapper.
//   • ONE argv probe per concern per poll, no shell: `pgrep -x vncviewer`
//     (session), `ping -c1 -W1` (reachability + RTT), `nc -z -w1` (VNC
//     port). Poll cadence: refreshIntervalSec (2–60, default 5), 1 Hz while
//     the popup is open (pollFast from BarWidget).
//   • The viewer itself is NEVER a captive Process — it is launched
//     detached via ctx.run (ServiceRoot connects requestConnect), so the
//     GUI outlives this service's lifecycle. Disconnect is `pkill -x
//     vncviewer` (single-session).
//   • State machine: "connected" | "disconnected" | "host-unreachable" |
//     "port-closed". viewer-missing is a hint (lastError) when a launch
//     request never produces a process, not a probe-derived state.
//
// v2 — saved connections (this network has no DNS; hosts are raw IPs):
//   • Connections index (name/host/port/user — NEVER credentials) persists
//     at $XDG_STATE_HOME/velocity/plugins/nikos.vnc-connections.json
//     (clock-weather cache pattern: FileView boot-load, atomic tmp+mv via
//     one-shot sh -c writer). This service is the file's only writer.
//   • Per-connection passwords live ENCRYPTED at
//     ~/.config/secrets/vnc/<id>.vnc (mode 600), produced by `vncpasswd -f`
//     reading the plaintext over STDIN only (NetworkService PSK idiom —
//     argv is world-readable in /proc). Ids are generated (c-<base36>),
//     never user input, so the sh -c paths are injection-safe.
//   • Probes target the ACTIVE connection ?? ad-hoc settings host/port
//     (targetHost/targetPort) — the pill and popup always describe what a
//     connect would hit.
//
// Configured by ServiceRoot.qml (entryPoints.service) — views never
// configure. Consumed by BarWidget/PanelBody via `import "." as VNC`.
// =============================================================================
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "lib/model.mjs" as Model

Item {
    id: root

    // Launch request → ServiceRoot runs it via ctx.run (argv[0] is in
    // manifest.commands; the secret never appears, only a file path).
    signal requestConnect(var argv)

    // ── settings (pushed by ServiceRoot from ctx.settings) ──────────────────
    property string host: "10.0.0.70"
    property int port: 5900
    property string passwordFile: ""
    property int refreshIntervalSec: 5
    property bool fullScreen: false
    property bool pollFast: false

    // ── saved-connection store ───────────────────────────────────────────────
    property var connections: []                 // normalized records, MRU-first
    property string activeConnectionId: ""       // "" = ad-hoc settings target

    readonly property var activeConnection: {
        if (root.activeConnectionId === "") return null
        var list = root.connections
        for (var i = 0; i < list.length; i++)
            if (list[i].id === root.activeConnectionId) return list[i]
        return null
    }

    // Everything downstream (probes, popup, status) binds to the target,
    // never to the raw settings — a saved connection overrides ad-hoc.
    readonly property string targetHost: {
        var c = root.activeConnection
        return c ? c.host : root.host
    }
    readonly property int targetPort: {
        var c = root.activeConnection
        return c ? c.port : root.port
    }
    readonly property string targetLabel: {
        var c = root.activeConnection
        if (!c) return root.host
        return c.name !== "" ? (c.name + " · " + c.host) : c.host
    }

    // Pill-friendly short label — the connection's name alone, else the host
    // (the bar pill is narrow; the popup hero carries the full targetLabel).
    readonly property string targetShort: {
        var c = root.activeConnection
        return c ? (c.name !== "" ? c.name : c.host) : root.host
    }

    // Transient form feedback (saved / errors) — cleared shortly after set.
    property string formHint: ""

    readonly property string _indexPath:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") || "~") + "/.local/state")
        + "/velocity/plugins/nikos.vnc-connections.json"
    readonly property string _secretsDir:
        (Quickshell.env("HOME") || "~") + "/.config/secrets/vnc"

    FileView { id: indexFile; path: root._indexPath }

    Component.onCompleted: root._ingestIndex()

    function _ingestIndex() {
        var txt = ""
        try { txt = indexFile.text() } catch (e) { return }
        var parsed = null
        try { parsed = JSON.parse(txt) } catch (e) { return }
        var merged = Model.mergeConnections(Array.isArray(parsed) ? parsed : [])
        if (merged.length > 0) root.connections = merged
    }

    // ── state machine ────────────────────────────────────────────────────────
    // "connected" | "disconnected" | "host-unreachable" | "port-closed"
    property string state: "disconnected"
    readonly property bool connected: state === "connected"

    // ── probe results (latest wins; recompute after each landing) ───────────
    property bool viewerRunning: false
    property bool hostReachable: false
    property bool portOpen: false
    property real lastRttMs: 0          // 0 = no sample yet
    property var rttHistory: []         // ring of recent RTT samples (ms)
    readonly property real avgRttMs: root._avgRtt()
    property real sessionStartedAt: 0   // epoch ms when the viewer appeared
    property string lastError: ""

    // ── private ──────────────────────────────────────────────────────────────
    property string _pingBuf: ""
    property string _pingErrBuf: ""
    property real _connectRequestedAt: 0

    // ── poll loop ────────────────────────────────────────────────────────────
    Timer {
        id: pollTimer
        interval: root.pollFast ? 1000 : Math.max(2, root.refreshIntervalSec) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // formHint auto-clear — feedback that lingers forever becomes noise.
    Timer {
        id: formHintTimer
        interval: 4000
        onTriggered: root.formHint = ""
    }

    function _hint(text) {
        root.formHint = text
        formHintTimer.restart()
    }

    // ── public API ───────────────────────────────────────────────────────────
    function configure(values) {
        var v = values || {}
        if (v.host !== undefined) root.host = String(v.host ?? "").trim()
        if (v.port !== undefined) root.port = Model.clampPort(v.port)
        if (v.passwordFile !== undefined) root.passwordFile = String(v.passwordFile ?? "").trim()
        if (v.refreshIntervalSec !== undefined) root.refreshIntervalSec = Model.clampIntervalSec(v.refreshIntervalSec)
        if (v.fullScreen !== undefined) root.fullScreen = !!v.fullScreen
    }

    function refresh() {
        root._probeViewer()
        root._probeHost()
    }

    // Ad-hoc connect (IPC `connect`, hero switch): the settings host/port.
    // Explicitly drops any active saved connection so the probes follow.
    function connectViewer() {
        root.activeConnectionId = ""
        root._launch({
            host: root.host, port: root.port,
            passwordFile: root.passwordFile, fullScreen: root.fullScreen
        })
    }

    // Saved connect (popup row CONNECT): target becomes this connection.
    function connectTo(id) {
        var c = null
        var list = root.connections
        for (var i = 0; i < list.length; i++)
            if (list[i].id === id) { c = list[i]; break }
        if (!c) {
            root.lastError = "unknown connection: " + id
            return
        }
        // Guard BEFORE flipping the target: re-aiming while a session runs
        // would mislabel the pill/hero as the new host while the viewer is
        // still attached to the old one.
        if (root.viewerRunning) {
            root._hint("a viewer session is already running — disconnect first")
            return
        }
        root.activeConnectionId = c.id
        root._launch({
            host: c.host, port: c.port, pwFile: c.pwFile,
            fullScreen: root.fullScreen || c.fullScreen
        })
    }

    function _launch(target) {
        if (root.viewerRunning) return
        var argv = Model.buildViewerArgs(target)
        if (argv === null) {
            root.lastError = "no host configured"
            return
        }
        root.lastError = ""
        root._connectRequestedAt = Date.now()
        root.requestConnect(argv)
        // Optimistic quick check — pgrep lands the authoritative transition.
        root._probeViewer()
    }

    function disconnectViewer() {
        if (!root.viewerRunning || killProc.running) return
        killProc.command = ["pkill", "-x", "vncviewer"]
        killProc.running = true
    }

    // ── connection CRUD ──────────────────────────────────────────────────────
    // draft: { id?, name, host, port, user, password, fullScreen? } — password
    // is PLAINTEXT from the form and only ever travels to vncpasswd stdin.
    // autoConnect (SAVE & CONNECT) launches the saved connection once its
    // record is durable — for password drafts that is AFTER vncpasswd lands,
    // so the viewer always finds the file it is pointed at.
    // Returns "" when accepted (async vncpasswd failures land in formHint),
    // else a human error for the form to show.
    function saveConnection(draft, autoConnect) {
        var d = draft || {}
        var isEdit = false
        var existing = null
        var list = root.connections
        for (var i = 0; i < list.length; i++)
            if (d.id !== undefined && list[i].id === d.id) { existing = list[i]; isEdit = true; break }

        var host = String(d.host ?? "").trim()
        if (!host) return "host is required"
        // Cap guard: creating past 12 would silently drop the new record in
        // mergeConnections' MRU sort (a fresh record has lastUsedMs 0, sorts
        // last, then the slice discards it). Reject instead of losing data.
        if (!isEdit && list.length >= 12)
            return "connection list is full (12) — delete one first"

        // Base record: edits keep their identity + createdAt; ids are
        // generated, so the sh -c writer paths stay injection-safe.
        var conn = Model.normalizeConnection({
            id: isEdit ? existing.id : Model.connectionId(Date.now()),
            name: d.name, host: host, port: d.port,
            user: d.user, fullScreen: d.fullScreen,
            lastUsedMs: isEdit ? existing.lastUsedMs : 0,
            createdAtMs: isEdit ? existing.createdAtMs : Date.now()
        })

        var password = String(d.password ?? "")
        if (password === "") {
            // No new secret: edits keep the old file, new records stay bare
            // (the viewer prompts itself).
            if (isEdit) conn.pwFile = existing.pwFile
            root._commitConnection(conn, !!autoConnect)
            return ""
        }
        if (pwWriter.running) return "still saving a password — try again"

        pwWriter.pendingConn = conn
        pwWriter.pendingSecret = password
        pwWriter.autoConnect = !!autoConnect
        pwWriter.path = root._secretsDir + "/" + conn.id + ".vnc"
        conn.pwFile = pwWriter.path
        // tmp+mv (indexWriter discipline): a failed vncpasswd must never
        // truncate the old secret an existing record may still point at —
        // edits reuse the same <id>.vnc path.
        // unbounded-ok: one-shot local write; killed by a 10s watchdog
        pwWriter.command = ["sh", "-c",
            'mkdir -p "$(dirname "$1")" && vncpasswd -f > "$1.tmp" && chmod 600 "$1.tmp" && mv -f "$1.tmp" "$1" || { rm -f "$1.tmp"; exit 1; }',
            "vncpasswd", pwWriter.path]
        pwWriter.running = true
        root._hint("storing password…")
        return ""
    }

    function _commitConnection(conn, autoConnect) {
        root.connections = Model.mergeConnections(root.connections.concat([conn]))
        root._persistIndex()
        root._hint("saved " + (conn.name !== "" ? conn.name : conn.host))
        // SAVE & CONNECT: the record (and its secret) is durable now.
        if (autoConnect && !root.viewerRunning) root.connectTo(conn.id)
    }

    function deleteConnection(id) {
        var victim = null
        var kept = []
        var list = root.connections
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === id) victim = list[i]
            else kept.push(list[i])
        }
        if (!victim) return
        root.connections = Model.mergeConnections(kept)
        root._persistIndex()
        if (root.activeConnectionId === id) root.activeConnectionId = ""
        if (victim.pwFile !== "") {
            if (rmWriter.running) rmWriter.pending.push(victim.pwFile)
            else rmWriter._fire(victim.pwFile)
        }
        root._hint("deleted " + (victim.name !== "" ? victim.name : victim.host))
    }

    function statusText() {
        var ep = Model.endpoint(root.targetHost, root.targetPort)
        if (root.state === "connected") {
            var dur = root.sessionStartedAt > 0 ? Model.fmtDuration((Date.now() - root.sessionStartedAt) / 1000) : ""
            return "up: " + root.targetLabel + (dur !== "" ? " (" + dur + ")" : "")
        }
        if (root.state === "host-unreachable") return "host unreachable: " + root.targetHost
        if (root.state === "port-closed") return "port closed: " + ep
        return "down: " + ep
    }

    function telemetryJson() {
        var c = root.activeConnection
        return JSON.stringify({
            state: root.state,
            host: root.targetHost,
            port: root.targetPort,
            connection: c ? (c.name !== "" ? c.name : c.id) : "",
            user: c ? c.user : "",
            hostReachable: root.hostReachable,
            portOpen: root.portOpen,
            rttMs: root.lastRttMs,
            rttAvgMs: root.avgRttMs,
            rttSamples: Array.isArray(root.rttHistory) ? root.rttHistory.length : 0,
            sessionMs: root.connected && root.sessionStartedAt > 0 ? Date.now() - root.sessionStartedAt : 0,
            lastError: root.lastError
        })
    }

    // ── state derivation (after any probe lands) ────────────────────────────
    function _recomputeState() {
        if (root.viewerRunning) {
            root.state = "connected"
        } else if (!root.hostReachable) {
            root.state = "host-unreachable"
        } else if (!root.portOpen) {
            root.state = "port-closed"
        } else {
            root.state = "disconnected"
        }
    }

    function _avgRtt() {
        var h = root.rttHistory
        if (!Array.isArray(h) || h.length === 0) return 0
        var sum = 0
        for (var i = 0; i < h.length; i++) sum += h[i]
        return sum / h.length
    }

    // Persist the connections index (atomic tmp+mv, cacheWriter idiom).
    // A write landing mid-run sets the dirty flag and onExited drains it, so
    // no update is ever dropped (a dropped _markUsed would desync MRU order).
    function _persistIndex() {
        if (indexWriter.running) { indexWriter.dirty = true; return }
        // unbounded-ok: one-shot local tmp+mv file write
        indexWriter.command = ["sh", "-c",
            'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1.tmp" && mv "$1.tmp" "$1"',
            "write", root._indexPath, JSON.stringify(root.connections)]
        indexWriter.running = true
    }

    // ── viewer probe: pgrep -x vncviewer ─────────────────────────────────────
    function _probeViewer() {
        if (viewerProc.running) return
        viewerProc.command = ["pgrep", "-x", "vncviewer"]
        viewerProc.running = true
    }

    // ── host probe: ping -c1 -W1 (RTT + reachability) ────────────────────────
    function _probeHost() {
        if (pingProc.running) return
        root._pingBuf = ""
        root._pingErrBuf = ""
        pingProc.command = ["ping", "-c1", "-W1", root.targetHost]
        pingProc.running = true
    }

    // ── port probe: nc -z -w1 (VNC server listening?) ────────────────────────
    // Runs only on reachable hosts — probing a down host would just burn the
    // 1 s timeout twice per poll.
    function _probePort() {
        if (!root.hostReachable || portProc.running) {
            if (!root.hostReachable) {
                root.portOpen = false
                root._recomputeState()
            }
            return
        }
        portProc.command = ["nc", "-z", "-w1", root.targetHost, String(root.targetPort)]
        portProc.running = true
    }

    // ── probe processes (one-shot, 10 s watchdog each; ping/nc carry their ───
    // ── own 1 s wire timeouts — the watchdog is a safety net only) ───────────
    Process {
        id: viewerProc   // unbounded-ok: one-shot local probe, killed by a 10s watchdog

        onExited: function(code) {
            var wasRunning = root.viewerRunning
            root.viewerRunning = Model.viewerRunningFromExit(code)
            if (root.viewerRunning && !wasRunning) {
                // 0→1 transition: session started (or our launch landed).
                root.sessionStartedAt = Date.now()
                root._connectRequestedAt = 0
                root.lastError = ""
                root._markUsed()
            } else if (!root.viewerRunning && wasRunning) {
                root.sessionStartedAt = 0
            } else if (!root.viewerRunning && root._connectRequestedAt > 0
                       && Date.now() - root._connectRequestedAt > 8000) {
                // Launch requested but no process ever appeared — the usual
                // suspect is vncviewer missing from the bar's PATH.
                root.lastError = "viewer did not start (vncviewer missing?)"
                root._connectRequestedAt = 0
            }
            root._recomputeState()
        }

        onRunningChanged: {
            if (viewerProc.running) { _viewerWatch.restart(); return }
            _viewerWatch.stop()
        }
    }
    Timer {
        id: _viewerWatch
        interval: 10000
        onTriggered: {
            if (!viewerProc.running) return
            viewerProc.running = false
            console.log("[nikos.vnc] pgrep probe timeout")
        }
    }

    Process {
        id: pingProc   // unbounded-ok: one-shot probe with its own 1s wire timeout

        stdout: SplitParser {
            onRead: data => { root._pingBuf += data + "\n" }
        }
        stderr: SplitParser {
            onRead: data => { root._pingErrBuf += data + "\n" }
        }

        onExited: function(code) {
            root.hostReachable = Model.pingOk(code)
            if (root.hostReachable) {
                var ms = Model.parsePingMs(root._pingBuf)
                if (ms !== null) {
                    root.lastRttMs = ms
                    root.rttHistory = Model.rttPush(root.rttHistory, ms)
                }
            } else {
                root.lastRttMs = 0
                root.rttHistory = []
                // Don't clobber the "viewer did not start" hint with
                // transient probe noise while a launch is pending.
                var err = Model.sanitizeError(root._pingErrBuf)
                if (err !== "" && root._connectRequestedAt === 0) root.lastError = err
            }
            root._probePort()   // port only matters on a reachable host
        }

        onRunningChanged: {
            if (pingProc.running) { _pingWatch.restart(); return }
            _pingWatch.stop()
        }
    }
    Timer {
        id: _pingWatch
        interval: 10000
        onTriggered: {
            if (!pingProc.running) return
            pingProc.running = false
            console.log("[nikos.vnc] ping probe timeout")
        }
    }

    Process {
        id: portProc   // unbounded-ok: one-shot probe with its own 1s wire timeout

        onExited: function(code) {
            root.portOpen = Model.portOpenFromExit(code)
            root._recomputeState()
        }

        onRunningChanged: {
            if (portProc.running) { _portWatch.restart(); return }
            _portWatch.stop()
        }
    }
    Timer {
        id: _portWatch
        interval: 10000
        onTriggered: {
            if (!portProc.running) return
            portProc.running = false
            console.log("[nikos.vnc] port probe timeout")
        }
    }

    // ── disconnect: pkill (single-session kills any viewer) ──────────────────
    Process {
        id: killProc   // unbounded-ok: one-shot local signal, no output to bound

        onExited: function(code) {
            if (code !== 0) root.lastError = "pkill exited " + code
            root._probeViewer()   // next pgrep lands the transition
        }

        onRunningChanged: {
            if (killProc.running) { _killWatch.restart(); return }
            _killWatch.stop()
        }
    }
    Timer {
        id: _killWatch
        interval: 10000
        onTriggered: {
            if (!killProc.running) return
            killProc.running = false
            console.log("[nikos.vnc] pkill timeout")
        }
    }

    // ── store writers (all one-shot, 10 s watchdogs) ─────────────────────────

    // Connections index — atomic tmp+mv JSON write (cacheWriter idiom).
    Process {
        id: indexWriter   // unbounded-ok: one-shot local tmp+mv file write
        property bool dirty: false   // set when a write was skipped mid-run

        onExited: function(code) {
            if (code !== 0) {
                root._hint("failed to write connections index (exit " + code + ")")
                console.log("[nikos.vnc] index write exit " + code)
            }
            if (indexWriter.dirty) {
                indexWriter.dirty = false
                root._persistIndex()
            }
        }

        onRunningChanged: {
            if (indexWriter.running) { _indexWatch.restart(); return }
            _indexWatch.stop()
        }
    }
    Timer {
        id: _indexWatch
        interval: 10000
        onTriggered: {
            if (!indexWriter.running) return
            indexWriter.running = false
            console.log("[nikos.vnc] index write timeout")
        }
    }

    // Password writer — vncpasswd reads the plaintext over STDIN (never
    // argv; NetworkService PSK idiom) and writes the encrypted file itself.
    Process {
        id: pwWriter   // unbounded-ok: secret travels over stdin, never argv
        property var pendingConn: null
        property string pendingSecret: ""
        property string path: ""
        property bool autoConnect: false
        stdinEnabled: true

        onStarted: {
            if (pendingSecret !== "") {
                write(pendingSecret + "\n")
                pendingSecret = ""
            }
        }

        onExited: function(code) {
            var conn = pendingConn
            if (!conn) return   // watchdog already reported the timeout
            var andConnect = autoConnect
            pendingConn = null
            autoConnect = false
            if (code !== 0) {
                root._hint("vncpasswd failed (exit " + code + ") — connection not saved")
                console.log("[nikos.vnc] vncpasswd exit " + code)
                return
            }
            // Index only records the connection once its secret is on disk.
            root._commitConnection(conn, andConnect)
        }

        onRunningChanged: {
            if (pwWriter.running) { _pwWatch.restart(); return }
            _pwWatch.stop()
        }
    }
    Timer {
        id: _pwWatch
        interval: 10000
        onTriggered: {
            if (!pwWriter.running) return
            pwWriter.running = false
            pwWriter.pendingConn = null
            pwWriter.pendingSecret = ""
            pwWriter.autoConnect = false
            root._hint("vncpasswd timed out — connection not saved")
            console.log("[nikos.vnc] vncpasswd timeout")
        }
    }

    // Password-file removal on delete (index entry is already gone by then).
    Process {
        id: rmWriter   // unbounded-ok: one-shot local unlink, no output to bound
        // Queued unlinks: a delete landing mid-run would otherwise orphan its
        // secret file forever (single Process, no retry path).
        property var pending: []

        function _fire(path) {
            command = ["sh", "-c", 'rm -- "$1"', "rm", path]
            running = true
        }

        onExited: function(code) {
            if (code !== 0) console.log("[nikos.vnc] password-file rm exit " + code)
            if (pending.length > 0) _fire(pending.shift())
        }

        onRunningChanged: {
            if (rmWriter.running) { _rmWatch.restart(); return }
            _rmWatch.stop()
        }
    }
    Timer {
        id: _rmWatch
        interval: 10000
        onTriggered: {
            if (!rmWriter.running) return
            rmWriter.running = false
            console.log("[nikos.vnc] password-file rm timeout")
        }
    }

    // ── usage bookkeeping ────────────────────────────────────────────────────
    // A session that just came up on a saved connection stamps lastUsedMs and
    // re-sorts the store (MRU-first), so the popup's top row is what you
    // connected to last.
    function _markUsed() {
        if (root.activeConnectionId === "") return
        var id = root.activeConnectionId
        var list = root.connections
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === id) {
                var stamped = list[i]
                stamped.lastUsedMs = Date.now()
                root.connections = Model.mergeConnections(list)
                root._persistIndex()
                return
            }
        }
    }
}
