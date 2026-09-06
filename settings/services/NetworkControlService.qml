// =============================================================================
// NetworkControlService.qml — native NM state + wifi list (nmcli for actions)
// =============================================================================
//
// STATE is native (Quickshell.Bluetooth's sibling patterns from T9): the
// connection card (type/connected/iface/ssid/signal) and the wifi list rebuild
// from the Networking devices/networks models — zero forked state probes (the
// old code forked link/wifi-active/list nmcli queries every 3-10s). The wifi
// scanner is LEASED to the network section being on screen (the networks model
// only populates while scanning; continuous scanning wastes radio otherwise).
// IPv4 still rides one gated `ip route` probe (not exposed natively).
//
// ACTIONS stay nmcli (user-triggered, one process each): the connect flow's
// --ask/saved-profile handling and error taxonomy (wrong-password reprompt)
// are richer than the native requestConnectWithPsk path; the scan button
// keeps one bounded `nmcli rescan` fork to force fresh results NOW.
//
// connectionStatus is a nested var object → reassigned as a whole (via
// _setStatus) so QML change signals fire (in-place mutation does not).
// wifiNetworks reassigned as a new array for the same reason.
//
// wifiNetworks items: { ssid, signal(0-100), security, inUse, chan, bssid }
// — chan/bssid are not exposed natively and unused by the row; kept as
// empty strings for shape compatibility.
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Networking
import Quickshell.Io
import "../config" as Config
import "NetworkControlModel.js" as Model
import "History.js" as History

Item {
    id: root
    visible: false

    property var connectionStatus: ({
        type: "",
        connected: false,
        iface: "",
        ssid: "",
        ip: "",
        signal: 0,
        subnet: "",       // "/24" — from IP4.ADDRESS
        gateway: "",      // from ip route / IP4.GATEWAY
        dns: "",          // first IP4.DNS entry
        mac: "",          // GENERAL.HWADDR
        linkSpeed: "",    // GENERAL.SPEED, e.g. "144 Mb/s"
        band: "",         // "2.4 GHz" / "5 GHz" — from enriched AP freq
        security: "",     // WPA2/WPA3/... of the connected network
        wifiEnabled: true // nmcli radio wifi state
    })

    property var wifiNetworks: []
    property bool scanning: false

    // SSID currently being connected to (cleared on success/failure). Drives
    // the row's connecting spinner/tint.
    property string connectingTo: ""

    // Last connect failure, classified (key/label from NetworkControlModel).
    // The signal carries the same info for views: WifiListView reopens the
    // passphrase prompt on "wrong-password" (Omarchy reprompt pattern).
    property string lastConnectError: ""
    signal connectFailed(string ssid, string reasonKey, string reasonLabel)

    // ── TRAFFIC HISTORY — /sys/class/net/<iface>/statistics sampled 1s,
    // ring-buffered 2-min (History.js, same pattern as CoreEngine).
    // rxRate/txRate are KB/s deltas, NOT cumulative counters.
    property var rxHistory: []
    property var txHistory: []
    property real rxRate: 0     // KB/s
    property real txRate: 0     // KB/s
    property real rxTotalMB: 0  // cumulative since shell start (for the card footer)
    property real txTotalMB: 0
    property real _lastRxBytes: -1
    property real _lastTxBytes: -1
    property real _lastTrafficTick: 0
    property bool _trafficLogged: false

    // Section-scoped (same lease as the scanner): the traffic card only exists
    // while the network section is on screen.
    readonly property bool _sectionVisible: Config.SharedState.dashboardVisible
          && Config.SharedState.controlSection === "network"

    Timer {
        id: trafficTimer
        interval: 1000
        running: root._sectionVisible && root.connectionStatus.connected
        repeat: true
        triggeredOnStart: true
        onTriggered: root._sampleTraffic()
    }

    Process {
        id: trafficProc
        command: []; running: false
        property string buffer: ""
        // SplitParser emits PER LINE — re-join with '\n' or the two-counter
        // split below collapses to one line and rates never compute (the old
        // "net traffic shows no data" bug).
        stdout: SplitParser { onRead: function(d) { trafficProc.buffer += d + "\n" } }
        onRunningChanged: {
            if (!running && trafficProc.buffer.length) {
                var lines = trafficProc.buffer.trim().split("\n")
                if (lines.length >= 2) {
                    var rx = parseInt(lines[0]) || 0
                    var tx = parseInt(lines[1]) || 0
                    var now = Date.now()
                    if (root._lastRxBytes >= 0 && root._lastTrafficTick > 0) {
                        var dt = (now - root._lastTrafficTick) / 1000
                        if (dt > 0.1) {
                            root.rxRate = Math.max(0, (rx - root._lastRxBytes) / dt / 1024)
                            root.txRate = Math.max(0, (tx - root._lastTxBytes) / dt / 1024)
                            root.rxTotalMB += root.rxRate * dt / 1024
                            root.txTotalMB += root.txRate * dt / 1024
                            if (!root._trafficLogged && (root.rxRate > 1 || root.txRate > 1)) {
                                root._trafficLogged = true
                                console.log("[NetControl] traffic live: rx " + root.rxRate.toFixed(0) + " KB/s iface " + root.connectionStatus.iface)
                            }
                        }
                    }
                    root._lastRxBytes = rx; root._lastTxBytes = tx; root._lastTrafficTick = now
                    root.rxHistory = History.appendHistory(root.rxHistory, now, root.rxRate, 120000, 120)
                    root.txHistory = History.appendHistory(root.txHistory, now, root.txRate, 120000, 120)
                }
                trafficProc.buffer = ""
            }
        }
    }

    function _sampleTraffic() {
        var iface = connectionStatus.iface
        if (!iface) {
            if (connectionStatus.connected) console.log("[NetControl] traffic: connected but no iface — skipping sample")
            return
        }
        if (trafficProc.running) return
        trafficProc.command = ["sh", "-c",
            "cat /sys/class/net/" + iface + "/statistics/rx_bytes " +
            "/sys/class/net/" + iface + "/statistics/tx_bytes"]
        trafficProc.running = true
    }

    // ── LINK QUALITY MONITOR — gated 1-of-1 ping (5s) while the section is on
    // screen and a link is up. Gives the telemetry card latency / jitter (EMA
    // of |Δ|) / loss (failures in the last 20 probes). -1 latency = unknown.
    property real latencyMs: -1
    property real jitterMs: 0
    property real lossPct: 0
    property var _pingResults: []   // last 20 booleans

    Timer {
        id: pingTimer
        interval: 5000
        running: root._sectionVisible && root.connectionStatus.connected
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!pingProc.running) pingProc.running = true
    }

    Process {
        id: pingProc
        command: ["ping", "-c", "1", "-W", "1", "1.1.1.1"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(d) { pingProc.buffer += d + "\n" } }
        onRunningChanged: {
            if (running) return
            var m = pingProc.buffer.match(/time=([\d.]+)/)
            if (m) {
                var v = parseFloat(m[1])
                if (root.latencyMs >= 0)
                    root.jitterMs = root.jitterMs * 0.7 + Math.abs(v - root.latencyMs) * 0.3
                root.latencyMs = v
            }
            root._pingResults = root._pingResults.concat([m !== null]).slice(-20)
            var fails = 0
            for (var i = 0; i < root._pingResults.length; i++) if (!root._pingResults[i]) fails++
            root.lossPct = root._pingResults.length ? fails / root._pingResults.length * 100 : 0
            pingProc.buffer = ""
        }
    }

    // -------------------------------------------------------------------------
    // NATIVE MODELS — device set + the wifi device + its networks
    // -------------------------------------------------------------------------
    // The connected managed device the card reports; wifi wins over wired.
    readonly property var activeDev: {
        const devs = Networking.devices.values || []
        let wired = null
        for (let i = 0; i < devs.length; i++) {
            const d = devs[i]
            if (!d.nmManaged || !d.connected) continue
            if (d.type === DeviceType.Wifi) return d
            if (d.type === DeviceType.Wired) wired = d
        }
        return wired
    }

    readonly property var wifiDev: {
        const devs = Networking.devices.values || []
        for (let i = 0; i < devs.length; i++)
            if (devs[i].type === DeviceType.Wifi) return devs[i]
        return null
    }

    // The connected network on the wifi device (null while the scanner lease
    // is off — the networks model only exists while scanning).
    readonly property var activeNet: {
        if (!activeDev || activeDev.type !== DeviceType.Wifi || !wifiDev) return null
        const nets = wifiDev.networks.values || []
        for (let i = 0; i < nets.length; i++)
            if (nets[i].connected) return nets[i]
        return null
    }

    // SCANNER LEASE: wifi data is only shown in the network section — scan
    // exactly while that section is on screen. Null-target-safe.
    Binding {
        target: root.wifiDev
        property: "scannerEnabled"
        value: Config.SharedState.dashboardVisible
              && Config.SharedState.controlSection === "network"
    }

    Component.onCompleted: console.log("[NetControl] native: nm=" +
        (Networking.backend === NetworkBackendType.NetworkManager) +
        " type=" + connectionStatus.type + " ssid=" + connectionStatus.ssid)

    // Fires only while the scanner lease is on (section visible) — settles and
    // hotplug are visible in the journal.
    onWifiNetworksChanged: console.log("[NetControl] wifi now " + wifiNetworks.length)

    // Registry enumeration is async — resync when models change.
    Connections {
        target: Networking.devices
        function onValuesChanged() { root._syncNativeStatus() }
    }
    Connections {
        target: root.wifiDev ? root.wifiDev.networks : null
        function onValuesChanged() { root._collectWifi() }
    }

    // -------------------------------------------------------------------------
    // STATE SYNC — rebuild the card + list from live native objects (no forks)
    // -------------------------------------------------------------------------
    function _syncNativeStatus() {
        const d = activeDev
        if (!d) {
            _setStatus({ type: "", connected: false, iface: "", ssid: "", signal: 0 })
            return
        }
        const isWifi = (d.type === DeviceType.Wifi)
        const n = activeNet
        _setStatus({
            type: isWifi ? "wifi" : "ethernet",
            connected: true,
            iface: d.name,
            ssid: (isWifi && n) ? n.name : "",
            signal: (isWifi && n) ? Math.round(n.signalStrength * 100) : 0,
            security: (isWifi && n) ? _secString(n.security) : ""
        })
    }

    // WifiNetwork.security is an enum — map to the row's display vocabulary.
    function _secString(sec) {
        switch (sec) {
            case WifiSecurityType.Wpa3SuiteB192:
            case WifiSecurityType.Sae:          return "WPA3"
            case WifiSecurityType.Wpa2Eap:
            case WifiSecurityType.Wpa2Psk:      return "WPA2"
            case WifiSecurityType.WpaEap:
            case WifiSecurityType.WpaPsk:       return "WPA"
            case WifiSecurityType.StaticWep:
            case WifiSecurityType.DynamicWep:   return "WEP"
            case WifiSecurityType.Leap:         return "LEAP"
            case WifiSecurityType.Owe:          return "OWE"
            case WifiSecurityType.Open:         return ""
            default:                            return "SECURE"
        }
    }

    function _collectWifi() {
        if (!wifiDev) {
            if (root.wifiNetworks.length > 0) root.wifiNetworks = []
            return
        }
        const nets = wifiDev.networks.values || []
        const best = {}
        for (let i = 0; i < nets.length; i++) {
            const n = nets[i]
            const ssid = n.name
            if (!ssid) continue
            const sig = Math.round((n.signalStrength || 0) * 100)
            const row = {
                ssid: ssid, signal: sig, security: _secString(n.security),
                inUse: n.connected, chan: "", bssid: "", band: ""
            }
            const e = root._enrichBySsid[ssid]       // chan/bssid from nmcli fork
            if (e) { row.chan = e.chan; row.bssid = e.bssid; row.band = e.band; row.freq = e.freq || 0 }
            const existing = best[ssid]
            if (!existing || sig > existing.signal) best[ssid] = row
            else if (row.inUse) best[ssid].inUse = true
        }
        const arr = []
        for (let s in best)
            if (Object.prototype.hasOwnProperty.call(best, s)) arr.push(best[s])
        arr.sort(function(a, b) { return b.signal - a.signal })
        // Reassign ONLY on real content change: a new array identity resets the
        // section list's Repeater (every row delegate destroyed + recreated).
        // The sweep (3s) and networks.valuesChanged (fires per network while a
        // scan settles — see the journal bursts) would otherwise churn the rows
        // constantly, killing clicks mid-press and the inline password editor.
        if (_sameWifiList(root.wifiNetworks, arr)) return
        root.wifiNetworks = arr
    }

    // Position-wise comparison of two collected lists (both sorted the same
    // way, so equal content lands in equal slots).
    function _sameWifiList(a, b) {
        if (a.length !== b.length) return false
        for (let i = 0; i < a.length; i++) {
            const x = a[i], y = b[i]
            if (x.ssid !== y.ssid || x.signal !== y.signal ||
                x.security !== y.security || x.inUse !== y.inUse ||
                x.chan !== y.chan || x.bssid !== y.bssid) return false
        }
        return true
    }

    // -------------------------------------------------------------------------
    // LINK PROBE — one gated fork per sweep for everything the native models
    // don't expose: route (src + via gateway), device details (HWADDR, SPEED,
    // IP4 address/subnet, DNS), and the wifi radio state.
    // -------------------------------------------------------------------------
    Process {
        id: linkProbe
        command: []; running: false
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { linkProbe.buffer += data + "\n" } }
        onRunningChanged: {
            if (running) return
            root._absorbLinkProbe(linkProbe.buffer)
            linkProbe.buffer = ""
        }
    }

    function _sampleLink() {
        if (linkProbe.running) return
        var iface = connectionStatus.iface || "any"
        linkProbe.command = ["sh", "-c",
            "ip -4 route get 1 2>/dev/null;" +
            "nmcli device show " + iface + " 2>/dev/null;" +
            "nmcli radio wifi 2>/dev/null"]
        linkProbe.running = true
    }

    function _absorbLinkProbe(out) {
        var patch = {}
        var lines = out.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var L = lines[i], m
            if ((m = L.match(/IP4\.ADDRESS\[\d+\]:\s*([\d.]+)\/(\d+)/))) { patch.ip = m[1]; patch.subnet = "/" + m[2] }
            else if ((m = L.match(/IP4\.GATEWAY:\s*([\d.]+)/))) patch.gateway = m[1]
            else if ((m = L.match(/IP4\.DNS\[\d+\]:\s*([\d.]+)/)) && !patch.dns) patch.dns = m[1]
            else if ((m = L.match(/GENERAL\.HWADDR:\s*(\S+)/))) patch.mac = m[1]
            else if ((m = L.match(/GENERAL\.SPEED:\s*(.+)$/))) patch.linkSpeed = m[1].trim()
            else if ((m = L.match(/src\s+([\d.]+)/)) && !patch.ip) patch.ip = m[1]
            else if ((m = L.match(/via\s+([\d.]+)/)) && !patch.gateway) patch.gateway = m[1]
            else if (L.trim() === "enabled" || L.trim() === "disabled") patch.wifiEnabled = (L.trim() === "enabled")
        }
        if (Object.keys(patch).length) _setStatus(patch)
    }

    // -------------------------------------------------------------------------
    // AP ENRICHMENT — chan/bssid/band are not on the native networks model.
    // One bounded `nmcli -t dev wifi list` fork (list only, no forced scan)
    // after each RESCAN and at most every 20s while the section is visible,
    // merged into the existing rows by SSID. Terse output escapes ':' inside
    // values as '\:' — swap for a sentinel BEFORE splitting (see memory note).
    // -------------------------------------------------------------------------
    property real _lastEnrich: 0

    Process {
        id: enrichProc
        command: []; running: false
        property string buffer: ""
        stdout: SplitParser { onRead: function(d) { enrichProc.buffer += d + "\n" } }
        onRunningChanged: {
            if (running) return
            root._absorbEnrich(enrichProc.buffer)
            enrichProc.buffer = ""
        }
    }

    function _sampleEnrich() {
        if (enrichProc.running) return
        var now = Date.now()
        if (now - root._lastEnrich < 20000) return
        root._lastEnrich = now
        enrichProc.command = ["sh", "-c",
            "nmcli -t -f SSID,BSSID,CHAN,FREQ,SIGNAL,SECURITY device wifi list 2>/dev/null"]
        enrichProc.running = true
    }

    // Enrichment cache (ssid → {bssid, chan, band}) — merged into every row
    // _collectWifi builds, so the native resync can never wipe it (that was
    // producing a wipe/re-add churn every sweep).
    property var _enrichBySsid: ({})

    function _absorbEnrich(out) {
        var bySsid = {}
        var lines = out.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split("\\:").join("\u0001").split(":")
            if (parts.length < 5) continue
            var ssid = parts[0].split("\u0001").join(":")
            if (!ssid) continue                      // hidden AP — nothing to merge onto
            var freq = parseInt(parts[3]) || 0
            bySsid[ssid] = {
                bssid: parts[1].split("\u0001").join(":").toLowerCase(),
                chan: parts[2] || "--",
                freq: freq,
                band: freq >= 5000 ? "5 GHz" : (freq > 0 ? "2.4 GHz" : "")
            }
        }
        root._enrichBySsid = bySsid
        _collectWifi()                               // single merge path (no-churn)
        var active = bySsid[connectionStatus.ssid]
        if (active && connectionStatus.band !== active.band) _setStatus({ band: active.band })
    }

    // -------------------------------------------------------------------------
    // WIFI RADIO — nmcli radio wifi on/off (user-triggered, header toggle)
    // -------------------------------------------------------------------------
    Process {
        id: radioProc
        property string buffer: ""
        stdout: SplitParser { onRead: function(d) { radioProc.buffer += d } }
        onExited: {
            radioProc.buffer = ""
            root.refreshStatus()
        }
    }

    function toggleWifi() {
        radioProc.command = ["sh", "-c",
            "nmcli radio wifi " + (connectionStatus.wifiEnabled ? "off" : "on")]
        radioProc.running = true
        CommandService.pushLog("[network] wifi radio " + (connectionStatus.wifiEnabled ? "off" : "on"), "output")
    }

    // -------------------------------------------------------------------------
    // SWEEP — 3s while the network section is on screen: native resync (zero
    // forks; catches per-device/network property drift between model signals)
    // + the one gated IPv4 probe.
    // -------------------------------------------------------------------------
    Timer {
        interval: 3000
        running: Config.SharedState.dashboardVisible
              && Config.SharedState.controlSection === "network"
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root._syncNativeStatus()
            root._collectWifi()
            root._sampleLink()
            root._sampleEnrich()
        }
    }

    // -------------------------------------------------------------------------
    // SCAN — one bounded nmcli rescan to force fresh results NOW, then collect
    // from the native model after the kernel settles.
    // -------------------------------------------------------------------------
    Process {
        id: rescanProc
        property string buffer: ""
        command: ["sh", "-c", "nmcli device wifi rescan 2>/dev/null; exit 0"]
        stdout: SplitParser { onRead: function(data) { rescanProc.buffer += data } }
        stderr: SplitParser { onRead: function(data) { rescanProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                rescanProc.buffer = ""
                rescanSettleTimer.restart()
            }
        }
    }

    Timer {
        id: rescanSettleTimer
        interval: 2000
        repeat: false
        onTriggered: {
            root.scanning = false
            root._collectWifi()
            root._lastEnrich = 0        // fresh scan → always re-enrich
            root._sampleEnrich()
        }
    }

    // Safety valve — if rescan never completes, clear the spinner.
    Timer {
        id: scanTimeoutTimer
        interval: 10000
        repeat: false
        onTriggered: {
            if (root.scanning) {
                root.scanning = false
                CommandService.pushLog("[network] scan timed out", "warning")
                root._collectWifi()
            }
        }
    }

    function scanWifi() {
        if (root.scanning) return   // silent — button already disabled in UI
        root.scanning = true
        CommandService.pushLog("[network] scanning wifi...", "output")
        rescanProc.running = true
        scanTimeoutTimer.restart()
    }

    function refreshList(fromScan) { root._collectWifi() }
    function refreshStatus() {
        root._syncNativeStatus()
        root._collectWifi()
        root._sampleLink()
    }

    // -------------------------------------------------------------------------
    // CONNECT / DISCONNECT — nmcli (see header: error taxonomy + saved profiles)
    // -------------------------------------------------------------------------
    Process {
        id: connectProc
        property string lastSsid: ""
        property string buffer: ""
        // The PSK travels over stdin, never argv — argv is world-readable in
        // /proc for the lifetime of the command (Omarchy enterpriseConnect
        // pattern: stdinEnabled + write() on start, wiped immediately after).
        property string pendingSecret: ""
        stdinEnabled: true
        stdout: SplitParser { onRead: function(data) { connectProc.buffer += data } }
        stderr: SplitParser { onRead: function(data) { connectProc.buffer += data } }
        onStarted: {
            if (pendingSecret !== "") {
                write(pendingSecret + "\n")
                pendingSecret = ""
            }
        }
        onExited: function(code) {
            if (code === 0) {
                CommandService.pushLog("[network] connected to " + connectProc.lastSsid, "success")
                root.refreshStatus()
            } else {
                var r = Model.connectFailureReason(connectProc.buffer)
                root.lastConnectError = r.label
                CommandService.pushLog("[network] connect failed: " + r.label, "error")
                root.connectFailed(connectProc.lastSsid, r.key, r.label)
            }
            root.connectingTo = ""          // clear connecting state (success or failure)
            connectProc.buffer = ""
        }
    }

    function connectWifi(ssid, password) {
        if (!ssid || ssid.length === 0) {
            CommandService.pushLog("error: no ssid given", "error")
            return
        }
        connectProc.lastSsid = ssid
        root.connectingTo = ssid           // mark this SSID as "connecting" (UI spinner)
        // --ask makes nmcli read missing secrets from stdin (a saved profile
        // supplies its stored PSK and never prompts; open networks skip the
        // prompt entirely). The password itself rides stdin, not argv.
        connectProc.pendingSecret = (password && password.length > 0) ? password : ""
        connectProc.command = ["nmcli", "--ask", "device", "wifi", "connect", ssid]
        connectProc.buffer = ""
        connectProc.running = true
        CommandService.pushLog("[network] connecting to " + ssid + "...", "output")
    }

    Process {
        id: disconnectProc
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { disconnectProc.buffer += data } }
        stderr: SplitParser { onRead: function(data) { disconnectProc.buffer += data } }
        onExited: function(code) {
            if (code === 0) CommandService.pushLog("[network] disconnected", "success")
            else CommandService.pushLog("[network] disconnect failed (exit " + code + "): " + disconnectProc.buffer.trim(), "error")
            disconnectProc.buffer = ""
            root.refreshStatus()
        }
    }

    function disconnectWifi() {
        var iface = root.connectionStatus.iface
        if (!iface || iface.length === 0) {
            CommandService.pushLog("error: no active interface", "error")
            return
        }
        disconnectProc.command = ["nmcli", "device", "disconnect", iface]
        disconnectProc.buffer = ""
        disconnectProc.running = true
    }

    // -------------------------------------------------------------------------
    // HELPERS
    // -------------------------------------------------------------------------

    // Reassign the whole object so change signals fire (nested-var gotcha).
    function _setStatus(patch) {
        root.connectionStatus = Object.assign({}, root.connectionStatus, patch)
    }
}
