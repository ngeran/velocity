// =============================================================================
// TailscaleService — plugin-internal qmldir singleton (nikos.wireguard)
// =============================================================================
// `tailscale status --json` poller + up/down/exit-node actions. Presence is
// probed once at startup (velocity.shot pattern); while the binary is missing
// the poller never starts and the service reports NotInstalled — the truthful
// state until the host lands tailscale on the bar PATH.
// Ported from ngeran.wireguard (Omarchy) TailscaleService.qml.
// =============================================================================
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "lib/model.mjs" as Model

Item {
    id: root

    // ── settings (pushed by ServiceRoot from ctx.settings) ──────────────────
    // Closed-panel cadence is floored at 5s: `status --json` is heavier than
    // the nmcli terse probe next door.
    property int refreshIntervalSec: 5
    property bool pollFast: false   // panel open → 2s cadence

    // ── presence ────────────────────────────────────────────────────────────
    property bool _installed: true   // optimistic until the probe answers
    property bool _probeDone: false
    readonly property bool installed: _installed

    // ── status ──────────────────────────────────────────────────────────────
    // Running/NeedsLogin/Stopped/Starting from the daemon; NotInstalled and
    // Unavailable are this service's own verdicts (missing binary / no JSON).
    property string backendState: "Unknown"
    readonly property bool running: backendState === "Running"
    readonly property bool needsLogin: backendState === "NeedsLogin"
    readonly property bool stopped: backendState === "Stopped"
    readonly property bool starting: backendState === "Starting"
    property string authUrl: ""
    property var self: ({})
    property var peers: []
    property var exitNode: null
    property var health: []
    property string tailnetName: ""

    readonly property int peersOnline: _countPeers(true)
    readonly property int directPeers: _countPath("direct")
    readonly property int relayPeers: _countPath("relay")

    // Peers are the honest counters (self sums are loopback-heavy); rx/tx are
    // summed across them and diffed against the previous poll for rates.
    property var counters: ({})
    property var rates: ({})
    property var _lastCounters: null
    property real _lastCountersAt: 0

    readonly property bool busy: statusProc.running || actionProc.running
    property string lastError: ""

    // ── public API ──────────────────────────────────────────────────────────
    function configure(values) {
        if (!values) return
        var sec = Number(values.refreshIntervalSec)
        if (!isNaN(sec) && sec > 0) refreshIntervalSec = sec
    }

    function refresh() {
        if (!_probeDone || !installed) return
        if (statusProc.running) return
        _statusStarted = true
        statusProc.running = true
    }

    // `tailscale up` prints the auth URL then times out against an
    // unauthenticated node — the daemon keeps the URL pending and the poller
    // surfaces it, so a timeout here is not an error.
    function connect() {
        if (!installed || actionProc.running) return
        _actionBuf = ""
        actionProc.command = ["tailscale", "up", "--timeout=10s"]
        actionProc.running = true
    }

    function disconnect() {
        if (!installed || actionProc.running) return
        _actionBuf = ""
        actionProc.command = ["tailscale", "down"]
        actionProc.running = true
    }

    function toggle() {
        if (running) disconnect()
        else connect()
    }

    // key "" / "off" / "none" clears; otherwise a peer id, hostName, dnsName
    // or IP. Returns an IPC-facing status string.
    function setExitNode(key) {
        if (!installed) return "tailscale is not installed"
        if (busy) return "busy"
        var wanted = String(key || "")
        if (wanted === "" || wanted === "off" || wanted === "none") {
            _actionBuf = ""
            actionProc.command = ["tailscale", "set", "--exit-node="]
            actionProc.running = true
            return "exit node cleared"
        }
        var peer = _findPeer(wanted)
        if (!peer) return "no such peer: " + wanted
        var target = (peer.ips && peer.ips.length > 0) ? peer.ips[0] : peer.dnsName
        if (!target) return "no such peer: " + wanted
        _actionBuf = ""
        actionProc.command = ["tailscale", "set", "--exit-node", target]
        actionProc.running = true
        return "exit node: " + target
    }

    function statusText() {
        if (!installed) return "tailscale: not installed"
        if (running) return "tailscale: up (" + peersOnline + "/" + peers.length + " peers)"
        if (needsLogin) return "tailscale: needs login"
        return "tailscale: " + backendState.toLowerCase()
    }

    function telemetryJson() {
        return JSON.stringify({
            installed: installed,
            backendState: backendState,
            authUrl: authUrl,
            tailnet: tailnetName,
            hostName: self && self.hostName ? self.hostName : "",
            dnsName: self && self.dnsName ? self.dnsName : "",
            ips: self && self.ips ? self.ips : [],
            peers: peers.length,
            peersOnline: peersOnline,
            direct: directPeers,
            relay: relayPeers,
            exitNode: exitNode
                ? (exitNode.hostName || exitNode.dnsName
                   || (exitNode.ips && exitNode.ips.length > 0 ? exitNode.ips[0] : ""))
                : "",
            rxBytes: counters && counters.rx ? counters.rx : 0,
            txBytes: counters && counters.tx ? counters.tx : 0,
            rxRate: rates && rates.rx ? rates.rx : 0,
            txRate: rates && rates.tx ? rates.tx : 0,
            health: health
        })
    }

    function _findPeer(key) {
        var k = String(key || "")
        for (var i = 0; i < peers.length; i++) {
            var p = peers[i]
            if (p.id === k || p.hostName === k || p.dnsName === k) return p
            if (p.ips && p.ips.indexOf(k) >= 0) return p
        }
        return null
    }

    function _countPeers(online) {
        var n = 0
        for (var i = 0; i < peers.length; i++)
            if (peers[i].online === online) n++
        return n
    }

    function _countPath(kind) {
        var n = 0
        for (var i = 0; i < peers.length; i++) {
            var p = peers[i]
            if (!p.online) continue
            if (kind === "direct" && p.curAddr !== "") n++
            else if (kind === "relay" && p.curAddr === "" && p.relay !== "") n++
        }
        return n
    }

    // ── status ingestion ────────────────────────────────────────────────────
    function _applyStatus(raw) {
        var parsed = Model.parseTailscaleStatus(raw)
        if (!parsed) {
            // Daemon down / CLI printed noise: keep the last peer list so the
            // panel doesn't blank during a blip, but flag the backend.
            backendState = "Unavailable"
            return
        }
        backendState = parsed.backendState
        authUrl = parsed.authUrl
        tailnetName = parsed.tailnetName
        self = parsed.self
        peers = parsed.peers
        exitNode = parsed.exitNode
        health = parsed.health

        var rx = 0
        var tx = 0
        for (var i = 0; i < parsed.peers.length; i++) {
            rx += parsed.peers[i].rx
            tx += parsed.peers[i].tx
        }
        var now = Date.now()
        var summed = { sum: { rx: rx, tx: tx } }
        rates = Model.computeRates(_lastCounters, summed, now - _lastCountersAt)
        counters = { rx: rx, tx: tx }
        _lastCounters = summed
        _lastCountersAt = now
    }

    // ── action error triage ─────────────────────────────────────────────────
    function _applyActionError(raw) {
        var text = String(raw || "").trim()
        if (text === "") { lastError = ""; return }
        // Fresh logins print the URL then time out — the poll surfaces it.
        if (/timeout waiting for Tailscale|To authenticate/i.test(text)) return
        if (/operator|access denied|permission/i.test(text)) {
            lastError = "tailscale control needs: tailscale set --operator=$USER"
            return
        }
        lastError = Model.sanitizeError(text)
    }

    Component.onCompleted: presenceProbe.running = true

    // ── presence probe (one-shot at mount, velocity.shot pattern) ───────────
    Process {   // unbounded-ok: one-shot presence probe at mount
        id: presenceProbe
        command: ["sh", "-c", "command -v tailscale >/dev/null 2>&1"]   // commands-ok: shell-builtin presence probe — tailscale itself is declared
        running: false

        onExited: function(code) {
            root._probeDone = true
            root._installed = code === 0
            if (!root._installed) {
                root.backendState = "NotInstalled"
                console.log("[nikos.wireguard] tailscale not found on PATH — TailscaleService idle")
            } else {
                root.refresh()
            }
        }
    }

    // ── status poll ─────────────────────────────────────────────────────────
    Timer {
        interval: root.pollFast ? 2000 : Math.max(5, root.refreshIntervalSec) * 1000
        running: root.installed && root._probeDone
        repeat: true
        onTriggered: root.refresh()
    }

    property bool _statusStarted: false
    property string _statusBuf: ""

    Process {   // unbounded-ok: local CLI poll, killed by a 10s watchdog
        id: statusProc

        command: ["tailscale", "status", "--json"]

        stdout: SplitParser { onRead: data => { root._statusBuf += data + "\n" } }
        stderr: SplitParser { onRead: data => { root._statusBuf += data + "\n" } }

        onRunningChanged: {
            if (statusProc.running) { statusWatch.restart(); return }
            statusWatch.stop()
            if (!root._statusStarted) return   // watchdog kill — already applied
            root._statusStarted = false
            var buf = root._statusBuf
            root._statusBuf = ""
            root._applyStatus(buf)
        }
    }

    Timer {
        id: statusWatch
        interval: 10000
        onTriggered: {
            if (!statusProc.running) return
            root._statusStarted = false   // onRunningChanged skips the dead fetch
            statusProc.running = false
            root._applyStatus("")   // parse-null path → Unavailable
        }
    }

    // ── actions (up / down / set) ───────────────────────────────────────────
    property string _actionBuf: ""

    Process {   // unbounded-ok: local CLI action, killed by a 45s watchdog
        id: actionProc

        stdout: SplitParser { onRead: data => { root._actionBuf += data + "\n" } }
        stderr: SplitParser { onRead: data => { root._actionBuf += data + "\n" } }

        onRunningChanged: {
            if (actionProc.running) { actionWatch.restart(); return }
            actionWatch.stop()
        }

        onExited: function(code) {
            if (code !== 0) root._applyActionError(root._actionBuf)
            else root.lastError = ""
            root._actionBuf = ""
            root.refresh()
        }
    }

    Timer {
        id: actionWatch
        interval: 45000   // `tailscale up --timeout=10s` can sit through a login
        onTriggered: {
            if (!actionProc.running) return
            actionProc.running = false
            root._applyActionError("tailscale action timed out")
            root.refresh()
        }
    }
}
