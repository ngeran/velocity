// =============================================================================
// WireGuardService — plugin-internal qmldir singleton (nikos.wireguard)
// =============================================================================
// NetworkManager-backed WireGuard state: tunnel list, the active tunnel's
// sysfs counters, per-uuid profile cache, and the action funnel (up/down/
// import/delete). Lives INSIDE the plugin (StorageService pattern) because
// plugins only see ctx — never bar services.
//
//   • Pure parsing lives in lib/model.mjs (node-tested); this file is only
//     the fetch/action wrapper.
//   • ONE argv nmcli probe per poll (no shell, no grep) — Model filters the
//     wireguard rows. Poll cadence: refreshIntervalSec (2–60, default 5),
//     1 Hz while the panel is open (pollFast from BarWidget).
//   • Counters are fork-free FileView reads on the ACTIVE tunnel's device
//     only (NetworkService idiom): reload is async, an idle link's unchanged
//     text never fires textChanged, so each sample arms a 250 ms settle
//     timer that absorbs the cache anyway — deltas decay to 0 instead of
//     freezing at the last nonzero sample.
//   • Import hardening: nmcli imports default connection.autoconnect=yes,
//     which would race a boot-time VPN up against ordinary networking —
//     every successful import is flipped to autoconnect=no before refresh.
//   • Handshake telemetry is NOT ported (Decision C — no root wg); the
//     surface stays as constants so the panel keeps ngeran's shape.
//
// Configured by ServiceRoot.qml (entryPoints.service) — views never
// configure. Consumed by BarWidget/PanelBody via `import "." as WireGuard`.
// =============================================================================
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "lib/model.mjs" as Model

Item {
    id: root

    // ── settings (pushed by ServiceRoot from ctx.settings) ──────────────────
    property int refreshIntervalSec: 5
    property bool pollFast: false

    // ── tunnel state ─────────────────────────────────────────────────────────
    property var tunnels: []
    // First live tunnel, else the first one still coming up — the pill and
    // panel both track this single "primary" notion.
    readonly property var activeTunnel: root._pickActive(root.tunnels)
    readonly property bool connected: root.activeTunnel !== null
        && root.activeTunnel.state === "activated"

    // ── traffic (active device only) ────────────────────────────────────────
    property var counters: ({})   // device → {rx, tx}
    property var rates: ({})      // device → {rx, tx} bytes/sec

    // ── profiles (uuid → {id, peers, dns}, raw strings) ─────────────────────
    readonly property var profiles: root._profileCache

    // ── lifecycle surface ────────────────────────────────────────────────────
    readonly property bool busy: actionProc.running || importProc.running
    property string lastError: ""

    // Handshake telemetry is not ported (Decision C) — a constant surface so
    // the panel and telemetryJson keep ngeran's shape.
    readonly property bool handshakeAvailable: false

    // ── private ──────────────────────────────────────────────────────────────
    property string _pendingUuid: ""        // optimistic toggle bookkeeping
    property var _profileCache: ({})
    property string _profileWantUuid: ""
    property string _counterDevice: ""
    property var _lastCounters: null
    property real _lastCountersAt: 0
    property bool _absorbedTick: false

    property string _stateBuf: ""
    property string _profileBuf: ""
    property string _actionBuf: ""
    property string _importBuf: ""

    // ── poll loop ────────────────────────────────────────────────────────────
    Timer {
        id: pollTimer
        interval: root.pollFast ? 1000 : Math.max(2, root.refreshIntervalSec) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.refresh()
            root._sampleCounters()
        }
    }

    // ── public API ───────────────────────────────────────────────────────────
    function configure(values) {
        var v = values || {}
        var s = (typeof v.refreshIntervalSec === "number") ? Math.round(v.refreshIntervalSec) : 5
        root.refreshIntervalSec = Math.max(2, Math.min(60, s))
    }

    function refresh() {
        if (stateProc.running) return
        root._stateBusy = true
        root._stateBuf = ""
        stateProc.command = ["nmcli", "-t",
            "-f", "NAME,UUID,TYPE,STATE,DEVICE,ACTIVE,TIMESTAMP",
            "connection", "show"]
        stateProc.running = true
        // While the panel is open, keep the profile (peer endpoints/DNS)
        // fresh too — 1 Hz nmcli show on one uuid is ngeran's cadence.
        if (root.pollFast && root.activeTunnel !== null) fetchProfile(root.activeTunnel.uuid)
    }

    function setTunnel(uuid, up) {
        if (root.busy) return
        var t = root._tunnelByUuid(uuid)
        if (t === null) return
        root._pendingUuid = uuid
        root._actionBuf = ""
        actionProc.command = up
            ? ["nmcli", "connection", "up", "uuid", uuid]
            : ["nmcli", "connection", "down", "uuid", uuid]
        actionProc.running = true
    }

    function toggleTunnel(uuid) {
        var t = root._tunnelByUuid(uuid)
        if (t === null) return
        setTunnel(uuid, t.state !== "activated")
    }

    // Pill right-click: down if anything is live/pending, else first tunnel up.
    function togglePrimary() {
        if (root.activeTunnel !== null) {
            setTunnel(root.activeTunnel.uuid, false)
        } else if (root.tunnels.length > 0) {
            setTunnel(root.tunnels[0].uuid, true)
        }
    }

    // IPC strings — every branch returns so callers (BarWidget verbs) can
    // surface the result directly.
    function setByName(key, up) {
        if (root.tunnels.length === 0) return "no tunnels"
        var t = root._findTunnel(key)
        if (t === null) return "no such tunnel: " + key
        if (root.busy) return "busy"
        var isUp = t.state === "activated" || t.state === "activating"
            || t.state === "ip-config" || t.state === "secondaries"
        if (isUp === up) return (up ? "already up: " : "already down: ") + t.name
        setTunnel(t.uuid, up)
        return (up ? "up: " : "down: ") + t.name
    }

    function importConf(path) {
        var p = String(path || "")
        if (p.indexOf("file://") === 0) p = decodeURIComponent(p.slice(7))
        if (p === "" || root.busy) return
        root._importBuf = ""
        importProc.command = ["nmcli", "connection", "import", "type", "wireguard", "file", p]
        importProc.running = true
    }

    // Panel drives the two-step confirm (first press arms, second presses
    // again); the service just deletes.
    function deleteTunnel(uuid) {
        if (root.busy) return
        var t = root._tunnelByUuid(uuid)
        if (t === null) return
        root._actionBuf = ""
        actionProc.command = ["nmcli", "connection", "delete", uuid]
        actionProc.running = true
    }

    function fetchProfile(uuid) {
        if (profileProc.running || uuid === "") return
        root._profileWantUuid = uuid
        root._profileBuf = ""
        profileProc.command = ["nmcli", "-t",
            "-f", "connection.id,wireguard.peers,ipv4.dns",
            "connection", "show", "uuid", uuid]
        profileProc.running = true
    }

    function statusText() {
        if (root.tunnels.length === 0) return "no tunnels"
        var t = root.activeTunnel
        if (t !== null && t.state === "activated") {
            var dev = t.device !== "--" && t.device !== "" ? " (" + t.device + ")" : ""
            return "up: " + t.name + dev
        }
        return "down"
    }

    function telemetryJson() {
        var t = root.activeTunnel
        var device = t !== null && t.device !== "--" && t.device !== "" ? t.device : ""
        var c = device !== "" && root.counters[device] !== undefined
            ? root.counters[device] : { rx: 0, tx: 0 }
        var r = device !== "" && root.rates[device] !== undefined
            ? root.rates[device] : { rx: 0, tx: 0 }
        var prof = t !== null && root._profileCache[t.uuid] !== undefined
            ? root._profileCache[t.uuid] : null
        var peers = prof !== null ? Model.parsePeerProfile(prof.peers) : []
        var endpoints = []
        for (var i = 0; i < peers.length; i++) {
            if (peers[i].endpoint !== "" && peers[i].endpoint !== "(none)") endpoints.push(peers[i].endpoint)
        }
        var now = Math.floor(Date.now() / 1000)
        return JSON.stringify({
            tunnel: t !== null ? t.name : null,
            uuid: t !== null ? t.uuid : "",
            device: device,
            state: t !== null ? t.state : "down",
            uptimeSec: t !== null && t.activatedAt > 0 ? Math.max(0, now - t.activatedAt) : 0,
            rxBytes: c.rx,
            txBytes: c.tx,
            rxRate: r.rx,
            txRate: r.tx,
            listenPort: 0,
            handshakeAvailable: false,
            lastHandshakeAgeSec: -1,
            peers: peers.length,
            endpoints: endpoints,
            dns: prof !== null ? prof.dns : ""
        })
    }

    // ── helpers ──────────────────────────────────────────────────────────────
    function _pickActive(list) {
        var pendingStates = { "activating": 1, "ip-config": 1, "secondaries": 1 }
        var live = null
        var pending = null
        for (var i = 0; i < list.length; i++) {
            if (list[i].state === "activated" && live === null) live = list[i]
            else if (pendingStates[list[i].state] === 1 && pending === null) pending = list[i]
        }
        return live !== null ? live : pending
    }

    function _tunnelByUuid(uuid) {
        for (var i = 0; i < root.tunnels.length; i++) {
            if (root.tunnels[i].uuid === uuid) return root.tunnels[i]
        }
        return null
    }

    // "" = live-or-first; otherwise match uuid, then name, then device.
    function _findTunnel(key) {
        if (key === "" || key === undefined || key === null) {
            return root.activeTunnel !== null ? root.activeTunnel
                : (root.tunnels.length > 0 ? root.tunnels[0] : null)
        }
        for (var i = 0; i < root.tunnels.length; i++) {
            if (root.tunnels[i].uuid === String(key)) return root.tunnels[i]
        }
        for (i = 0; i < root.tunnels.length; i++) {
            if (root.tunnels[i].name === String(key)) return root.tunnels[i]
        }
        for (i = 0; i < root.tunnels.length; i++) {
            if (root.tunnels[i].device === String(key)) return root.tunnels[i]
        }
        return null
    }

    function _applyState(raw) {
        root.tunnels = Model.parseTunnelLines(raw)

        // Optimistic toggle bookkeeping: once the poll sees the pending
        // tunnel out of its transition states (or gone), the hope is settled.
        if (root._pendingUuid !== "") {
            var t = root._tunnelByUuid(root._pendingUuid)
            if (t === null || (t.state !== "activating" && t.state !== "ip-config"
                && t.state !== "secondaries")) {
                root._pendingUuid = ""
            }
        }

        // Counters track the active tunnel's device; a device change is a
        // fresh counter baseline (deltas across devices are meaningless).
        var dev = ""
        if (root.activeTunnel !== null) {
            var d = root.activeTunnel.device
            if (d !== "" && d !== "--" && /^[A-Za-z0-9._-]+$/.test(d)) dev = d
        }
        if (dev !== root._counterDevice) {
            root._counterDevice = dev
            root._lastCounters = null
            root._lastCountersAt = 0
            root.counters = ({})
            root.rates = ({})
            if (dev !== "") root._sampleCounters()
        }
    }

    // ── traffic sampling (NetworkService FileView idiom) ────────────────────
    FileView {
        id: rxFile
        path: root._counterDevice !== ""
            ? "/sys/class/net/" + root._counterDevice + "/statistics/rx_bytes" : ""
        watchChanges: false
        printErrors: false
    }
    FileView {
        id: txFile
        path: root._counterDevice !== ""
            ? "/sys/class/net/" + root._counterDevice + "/statistics/tx_bytes" : ""
        watchChanges: false
        printErrors: false
        onTextChanged: { root._absorbedTick = true; root._absorbCounters() }
    }
    Timer {
        id: statsSettle
        interval: 250
        onTriggered: if (!root._absorbedTick) root._absorbCounters()
    }

    function _sampleCounters() {
        if (root._counterDevice === "") return
        root._absorbedTick = false
        rxFile.reload()      // ASYNC — a changed cache lands in txFile.onTextChanged,
        txFile.reload()      // an unchanged one decays via statsSettle above
        statsSettle.restart()
    }

    function _absorbCounters() {
        var rx = parseInt(rxFile.text(), 10)
        var tx = parseInt(txFile.text(), 10)
        if (isNaN(rx) || isNaN(tx) || root._counterDevice === "") return
        var now = Date.now()
        var current = {}
        current[root._counterDevice] = { rx: rx, tx: tx }
        root.counters = current
        root.rates = Model.computeRates(root._lastCounters, current,
            root._lastCountersAt > 0 ? now - root._lastCountersAt : 0)
        root._lastCounters = current
        root._lastCountersAt = now
    }

    // ── state probe ──────────────────────────────────────────────────────────
    property bool _stateBusy: false

    Process {
        id: stateProc   // unbounded-ok: one-shot local probe, killed by a 10s watchdog

        stdout: SplitParser {
            onRead: data => { root._stateBuf += data + "\n" }
        }

        onRunningChanged: {
            if (stateProc.running) { _stateWatch.restart(); return }
            _stateWatch.stop()
            if (!root._stateBusy) return   // watchdog kill — skip the dead fetch
            root._stateBusy = false
            root._applyState(root._stateBuf)
            root._stateBuf = ""
        }
    }
    Timer {
        id: _stateWatch
        interval: 10000
        onTriggered: {
            if (!stateProc.running) return
            root._stateBusy = false        // onRunningChanged skips the dead fetch
            stateProc.running = false
            console.log("[nikos.wireguard] nmcli state probe timeout")
        }
    }

    // ── profile fetch ────────────────────────────────────────────────────────
    Process {
        id: profileProc   // unbounded-ok: one-shot local probe, killed by a 10s watchdog

        stdout: SplitParser {
            onRead: data => { root._profileBuf += data + "\n" }
        }

        onRunningChanged: {
            if (profileProc.running) _profileWatch.restart()
            else _profileWatch.stop()
        }

        onExited: function(code) {
            if (code !== 0 || root._profileWantUuid === "") return
            var id = "", peers = "", dns = ""
            var lines = root._profileBuf.split(/\r?\n/)
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i]
                var cut = line.indexOf(":")
                if (cut <= 0) continue
                var key = line.slice(0, cut)
                var value = line.slice(cut + 1)
                if (value === "--" || value === "(none)") continue
                var text = Model.unescapeNmcli(value)
                if (key === "connection.id") id = text
                else if (key === "wireguard.peers") peers = text
                else if (key === "ipv4.dns") dns = text
            }
            var cache = {}
            for (var uuid in root._profileCache) cache[uuid] = root._profileCache[uuid]
            cache[root._profileWantUuid] = { id: id, peers: peers, dns: dns }
            root._profileCache = cache
        }
    }
    Timer {
        id: _profileWatch
        interval: 10000
        onTriggered: {
            if (!profileProc.running) return
            profileProc.running = false
            console.log("[nikos.wireguard] nmcli profile fetch timeout")
        }
    }

    // ── action funnel: up / down / delete ───────────────────────────────────
    Process {
        id: actionProc   // unbounded-ok: user-triggered one-shot, killed by a 45s watchdog (wg handshakes are slow)

        stderr: SplitParser {
            onRead: data => { root._actionBuf += data + "\n" }
        }

        onRunningChanged: {
            if (actionProc.running) _actionWatch.restart()
            else _actionWatch.stop()
        }

        onExited: function(code) {
            if (code === 0) {
                root.lastError = ""
            } else {
                root.lastError = root._actionBuf !== ""
                    ? Model.sanitizeError(root._actionBuf)
                    : "nmcli action timed out"
            }
            root.refresh()
        }
    }
    Timer {
        id: _actionWatch
        interval: 45000
        onTriggered: {
            if (!actionProc.running) return
            actionProc.running = false
        }
    }

    // ── .conf import (+ autoconnect hardening) ──────────────────────────────
    Process {
        id: importProc   // unbounded-ok: user-triggered one-shot, killed by a 10s watchdog

        stdout: SplitParser {
            onRead: data => { root._importBuf += data + "\n" }
        }
        stderr: SplitParser {
            onRead: data => { root._importBuf += data + "\n" }
        }

        onRunningChanged: {
            if (importProc.running) _importWatch.restart()
            else _importWatch.stop()
        }

        onExited: function(code) {
            if (code !== 0) {
                root.lastError = root._importBuf !== ""
                    ? Model.sanitizeError(root._importBuf)
                    : "import timed out"
                root.refresh()
                return
            }
            // nmcli prints: Connection 'name' (<uuid>) successfully added.
            var uuidMatch = root._importBuf.match(/\(([0-9a-fA-F-]{36})\)/)
            if (uuidMatch !== null) {
                // Hardening: imported profiles default autoconnect=yes, which
                // would race the VPN up at boot — flip it off (non-fatal).
                modifyProc.command = ["nmcli", "connection", "modify",
                    uuidMatch[1], "connection.autoconnect", "no"]
                modifyProc.running = true
            } else {
                root.refresh()
            }
        }
    }
    Timer {
        id: _importWatch
        interval: 10000
        onTriggered: {
            if (!importProc.running) return
            importProc.running = false
        }
    }

    Process {
        id: modifyProc   // unbounded-ok: one-shot local write, killed by a 10s watchdog

        onRunningChanged: {
            if (modifyProc.running) _modifyWatch.restart()
            else _modifyWatch.stop()
        }

        onExited: function(code) {
            if (code !== 0) {
                console.log("[nikos.wireguard] autoconnect hardening failed (non-fatal)")
            }
            root.refresh()
        }
    }
    Timer {
        id: _modifyWatch
        interval: 10000
        onTriggered: {
            if (!modifyProc.running) return
            modifyProc.running = false
        }
    }
}
