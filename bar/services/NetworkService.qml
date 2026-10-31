/** Version: 29 — native Quickshell.Networking for STATE (zero forks);
 ** nmcli only for ACTIONS (connect/disconnect/rescan/DNS/QR — stdin-carried
 ** PSK, error taxonomy); popup diagnostics as popup-gated one-shot probes.
 ** P2.2: this is the ONE network service — the settings dashboard's wifi
 ** list, engineer pane, latency payload, DNS and QR read the same instance
 ** through HostBridge (the old NetworkControlService is gone). Its section
 ** gates arrive as `dashboardLease`/`sectionLease`, pushed by
 ** SettingsBootstrap from SharedState — this file imports nothing from the
 ** settings tree. **/
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Io
import "../config" as Config
import "../lib/network-model.mjs" as Model
import "../lib/network-control-model.mjs" as ConnectModel
import "../lib/history.mjs" as History
import "../lib/netparse.mjs" as Netparse
import "../lib/netstats.mjs" as NetStats
import "../lib/netengineer.mjs" as NetEng

Item {
    id: root
    visible: false

    // =========================================================================
    // NATIVE STATE — Quickshell.Networking (event-driven NM client)
    // =========================================================================
    // The bar icon's state (type / SSID / connected / live signal) is pure
    // bindings. Signal of the CONNECTED network is association data — no scan
    // needed.

    property bool hasNetwork: Networking.backend === NetworkBackendType.NetworkManager

    // The connected managed device the bar reports on; wifi wins over wired.
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

    // The connected network on that device (its name is the SSID for wifi).
    readonly property var activeNet: {
        if (!activeDev) return null
        const nets = activeDev.networks.values || []
        for (let i = 0; i < nets.length; i++)
            if (nets[i].connected) return nets[i]
        return null
    }

    // The system's wifi device (scanner host) — null on wifi-less machines.
    readonly property var wifiDev: {
        const devs = Networking.devices.values || []
        for (let i = 0; i < devs.length; i++)
            if (devs[i].type === DeviceType.Wifi) return devs[i]
        return null
    }

    // SCANNER LEASE (Shibumi pattern): device.networks — and with it the
    // connected network's SSID + live signal — only exists while the wifi
    // scanner runs. Continuous scanning costs radio power for data only the
    // TrayCard popup and the settings network section show, so the scanner is
    // leased to either. Null-target-safe.
    Binding {
        target: root.wifiDev
        property: "scannerEnabled"
        value: root.popupOpen || root.sectionLease
    }

    // ── LEASES from the settings tree (pushed by SettingsBootstrap) ────────
    // The import-split law forbids importing the settings config here; the
    // bootstrap mirrors SharedState.dashboardVisible / controlSection into
    // these two properties (attach + every change).
    property bool dashboardLease: false   // dashboard window open (traffic history)
    property bool sectionLease: false     // NETWORK section on screen (sweep, ping, enrich, engineer)

    property bool isConnected: activeDev !== null
    property string connectionType: !activeDev ? ""
        : (activeDev.type === DeviceType.Wifi ? "wifi" : "ethernet")

    // SSID: live from the connected network while a scanner lease is active;
    // cached across popup re-opens (last value seen) so reopening is instant.
    // Cleared on disconnect so it can never go stale across networks.
    property string _lastSsid: ""
    onActiveNetChanged: {
        if (activeNet) root._lastSsid = activeNet.name
        console.log("[NetworkService] active network: " +
            (activeNet ? activeNet.name + " sig=" + activeNet.signalStrength : "none"))
    }
    property string ssid: activeNet ? activeNet.name
        : (isConnected ? root._lastSsid : "")

    // Live signal of the connected wifi. WifiNetwork.signalStrength is 0..1.
    property int signalStrength: (activeDev && activeDev.type === DeviceType.Wifi && activeNet)
        ? Math.round(activeNet.signalStrength * 100) : 0
    onSignalStrengthChanged: if (Config.DebugConfig.debugService)
        console.log("[NetworkService] signal " + signalStrength)

    // ── CONNECTION STATUS CARD (settings views + latency payload) ──────────
    // Nested var object → reassigned as a whole (via _setStatus) so QML change
    // signals fire (in-place mutation does not).
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
        ip6: "",          // first global/link IP6.ADDRESS (P4.1 card row)
        mac: "",          // GENERAL.HWADDR
        linkSpeed: "",    // GENERAL.SPEED, e.g. "144 Mb/s"
        band: "",         // "2.4 GHz" / "5 GHz" — from enriched AP freq
        security: "",     // WPA2/WPA3/... of the connected network
        wifiEnabled: true // radio state
    })

    // ── WIFI LIST ────────────────────────────────────────────────────────────
    // wifiNetworks items: { ssid, signal(0-100), security, inUse, chan, bssid }
    // — chan/bssid are not exposed natively; the nmcli enrich probe fills them.
    property var wifiNetworks: []
    property bool scanning: false

    // SSID currently being connected to (cleared on success/failure). Drives
    // the row's connecting spinner/tint.
    property string connectingTo: ""

    // Last connect failure, classified (key/label from network-control-model).
    // The signal carries the same info for views.
    property string lastConnectError: ""
    signal connectFailed(string ssid, string reasonKey, string reasonLabel)

    // ── POPUP DIAGNOSTICS (bar card; string rates, "" = no sample yet) ─────
    property string ipAddress: ""
    // Active interface — native, zero forks (the old default-route probe is
    // gone; the device name IS the iface).
    readonly property string iface: activeDev ? activeDev.name : ""
    property string rxRate: ""
    property string txRate: ""
    property string rxTotal: ""
    property string txTotal: ""
    property var _stats: null       // last sample {iface, rx, tx, t}

    // ── TRAFFIC HISTORY (dashboard: System Pulse + wifi chart) ─────────────
    // /sys/class/net/<iface>/statistics sampled 1s while the dashboard is
    // open, ring-buffered 2-min (history.mjs, same pattern as CoreEngine).
    // trafficRxKB/trafficTxKB are KB/s deltas, NOT cumulative counters. The
    // popup string rates above are folded from the SAME counter reads — one
    // FileView pair feeds both consumers.
    property var rxHistory: []
    property var txHistory: []
    property real trafficRxKB: 0    // KB/s
    property real trafficTxKB: 0    // KB/s
    property real rxTotalMB: 0      // cumulative since shell start
    property real txTotalMB: 0
    property real _lastRxBytes: -1
    property real _lastTxBytes: -1
    property real _lastTrafficTick: 0
    property bool _trafficLogged: false

    Timer {
        id: trafficTimer
        interval: 1000
        running: root.dashboardLease && root.connectionStatus.connected
        repeat: true
        triggeredOnStart: true
        onTriggered: root._sampleCounters()
    }

    // Dashboard lease = the System-Info tab is showing; its LOCAL IP / GEO /
    // gateway rows read connectionStatus.ip, which only the LINK probe fills
    // (the popup's fetch-on-open never runs for the dashboard). Sample on
    // open and on a slow tick while held — same probe the popup uses, at
    // dashboard cadence (user call: LOCAL IP showed "—" forever).
    onDashboardLeaseChanged: if (root.dashboardLease && root.isConnected) root._sampleLink()
    Timer {
        id: dashLinkTimer
        interval: 30000
        running: root.dashboardLease && root.isConnected
        repeat: true
        triggeredOnStart: true
        onTriggered: if (root.isConnected) root._sampleLink()
    }

    // 2s while the popup is open — rates want a short window to feel live.
    Timer {
        id: statsTimer
        interval: 2000
        repeat: true
        running: root.hasNetwork && root.popupOpen
        onTriggered: if (root.isConnected) root._sampleCounters()
    }

    // ── TRAFFIC — sysfs counters via FileView (zero forks) ──────────────────
    // Two FileViews on the active iface's rx/tx statistics files, reloaded by
    // the two timers above. Absorb runs on the TX file's change callback —
    // but an IDLE link's counters don't change, and FileView textChanged only
    // fires on an actual change, so each tick arms a 250ms settle timer that
    // absorbs the (unchanged) cache anyway: delta 0 decays the rates to zero
    // instead of freezing them at the last nonzero sample, and the resume
    // delta never spans the idle gap (Hr review). The old glued-counter
    // incident class is structurally gone — no parser at all.
    property bool _absorbedTick: false   // did this tick's reload land a change?
    FileView {
        id: rxFile
        path: root.iface !== ""
            ? "/sys/class/net/" + root.iface + "/statistics/rx_bytes" : ""
        watchChanges: false
        printErrors: false
    }
    FileView {
        id: txFile
        path: root.iface !== ""
            ? "/sys/class/net/" + root.iface + "/statistics/tx_bytes" : ""
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
        if (root.iface === "") {
            if (root.connectionStatus.connected) console.log("[NetworkService] traffic: connected but no iface — skipping sample")
            return
        }
        root._absorbedTick = false
        rxFile.reload()      // ASYNC — a changed cache lands in txFile.onTextChanged,
        txFile.reload()      // an unchanged one decays via statsSettle below
        statsSettle.restart()
    }

    function _absorbCounters() {
        var rx = parseInt(rxFile.text(), 10)
        var tx = parseInt(txFile.text(), 10)
        if (isNaN(rx) || isNaN(tx) || root.iface === "") return
        var now = Date.now()
        // Popup string rates (bar card; the fold guards iface changes/resets)
        var r = Model.throughputState(root._stats, root.iface, rx, tx, now)
        root.rxRate = r.rxRate
        root.txRate = r.txRate
        root.rxTotal = r.rxTotal
        root.txTotal = r.txTotal
        root._stats = r.state
        // Dashboard numeric history (KB/s deltas + 2-min rings)
        if (root._lastRxBytes >= 0 && root._lastTrafficTick > 0) {
            var dt = (now - root._lastTrafficTick) / 1000
            if (dt > 0.1) {
                root.trafficRxKB = Math.max(0, (rx - root._lastRxBytes) / dt / 1024)
                root.trafficTxKB = Math.max(0, (tx - root._lastTxBytes) / dt / 1024)
                root.rxTotalMB += root.trafficRxKB * dt / 1024
                root.txTotalMB += root.trafficTxKB * dt / 1024
                if (!root._trafficLogged && (root.trafficRxKB > 1 || root.trafficTxKB > 1)) {
                    root._trafficLogged = true
                    console.log("[NetworkService] traffic live: rx " + root.trafficRxKB.toFixed(0) + " KB/s iface " + root.iface)
                }
            }
        }
        root._lastRxBytes = rx; root._lastTxBytes = tx; root._lastTrafficTick = now
        root.rxHistory = History.appendHistory(root.rxHistory, now, root.trafficRxKB, 120000, 120)
        root.txHistory = History.appendHistory(root.txHistory, now, root.trafficTxKB, 120000, 120)
    }

    // ── LINK QUALITY MONITOR — TWO LEGS (math: lib/netstats.mjs, nexthop-
    // derived). 5s cadence while the NETWORK section is on screen and a link
    // is up: one ping to the internet anchor, then one to the gateway. Each
    // leg folds into percentiles + IPDV jitter + loss over the last 20
    // probes; gateway samples pair with internet samples of the same tick
    // into the WAN leg (internet minus gateway, with the inversion refusal —
    // a gateway answering slower than the internet behind it yields
    // "unknown", never a clamped 0.0 ms). latencyMs/jitterMs/lossPct stay as
    // the WAN-leg aliases WifiListView binds.
    property var _wanSamples: []    // last 20 {ok, rtt} — internet anchor
    property var _localSamples: []  // last 20 {ok, rtt} — gateway
    property var _wanLegPoints: []  // last 20 valid paired WAN points (ms)
    property var wanFold: null
    property var localFold: null
    property var wanLegFold: null
    property real wanLegMs: -1      // latest paired WAN point
    property string wanLegNote: ""  // why the WAN leg is unknown ("" = known)
    property real latencyMs: -1
    property real jitterMs: 0
    property real lossPct: 0

    Timer {
        id: pingTimer
        interval: 5000
        running: root.sectionLease && root.connectionStatus.connected
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!pingProc.running) pingProc.running = true
    }

    BoundedProcess {   // bounded: one-shot ping (P8.1)
        id: pingProc
        timeoutMs: 2500              // -W 1 plus connect slack
        command: ["ping", "-c", "1", "-W", "1", "1.1.1.1"]
        onDone: function (out) {
            var m = out.match(/time=([\d.]+)/)
            root._wanSamples = root._wanSamples.concat(
                [{ ok: m !== null, rtt: m !== null ? parseFloat(m[1]) : null }]).slice(-20)
            var gw = root.connectionStatus.gateway
            if (gw !== "") {
                gwPingProc.command = ["ping", "-c", "1", "-W", "1", gw]
                gwPingProc.run()
            } else {
                root.wanLegNote = "gateway unknown"
            }
            root._refold()
        }
    }

    BoundedProcess {   // bounded: one-shot gateway ping (P8.1)
        id: gwPingProc
        timeoutMs: 2500
        command: []
        onDone: function (out) {
            var m = out.match(/time=([\d.]+)/)
            root._localSamples = root._localSamples.concat(
                [{ ok: m !== null, rtt: m !== null ? parseFloat(m[1]) : null }]).slice(-20)
            root._refold()
            root._pairLatest()   // gateway sample completes the tick's pair
        }
    }

    function _refold() {
        root.wanFold = NetStats.fold(root._wanSamples)
        root.localFold = NetStats.fold(root._localSamples)
        var last = root.wanFold && root.wanFold.ok > 0 ? root._wanSamples[root._wanSamples.length - 1] : null
        root.latencyMs = last && last.ok ? last.rtt : -1
        root.jitterMs = root.wanFold ? root.wanFold.jitter : 0
        root.lossPct = root.wanFold ? root.wanFold.lossPct : 0
    }

    // Pair the newest tick: wan sample N with gateway sample N. Only the
    // gateway completion pairs — the internet probe of a tick always lands
    // first, so lengths align exactly there.
    function _pairLatest() {
        var n = Math.min(root._wanSamples.length, root._localSamples.length)
        if (n === 0) { root.wanLegNote = "sampling…" ; return }
        var t = root._wanSamples[n - 1], l = root._localSamples[n - 1]
        if (!t.ok) { root.wanLegNote = "internet probe lost"; return }
        if (!l.ok) { root.wanLegNote = "gateway unreachable"; return }
        var pt = NetStats.wanPoint(t.rtt, l.rtt)
        if (pt === null) {
            root.wanLegNote = "unknown — gateway answers slower than the internet (routers often deprioritize ICMP)"
            return
        }
        root.wanLegMs = pt
        root.wanLegNote = ""
        root._wanLegPoints = root._wanLegPoints.concat([pt]).slice(-20)
        root.wanLegFold = NetStats.fold(root._wanLegPoints.map(function(v) { return { ok: true, rtt: v } }))
    }

    // When the connection drops, clear the popup diagnostics + SSID cache and
    // the traffic baselines (no resume delta across the gap).
    onIsConnectedChanged: if (!isConnected) { root._lastSsid = ""; root._reset() }

    Component.onCompleted: {
        _syncNativeStatus()
        console.log(
            "[NetworkService] native: nm=" + hasNetwork +
            " type=" + connectionType + " ssid=" + ssid +
            " sig=" + signalStrength +
            (activeNet ? " rawSignal=" + activeNet.signalStrength : ""))
    }

    // Registry enumeration is async — resync the card + list when models
    // change (settles and hotplug are visible in the journal).
    Connections {
        target: Networking.devices
        function onValuesChanged() {
            root._syncNativeStatus()
            root._collectWifi()
            const devs = Networking.devices.values || []
            let s = ""
            for (let i = 0; i < devs.length; i++)
                s += " [" + devs[i].name + " t=" + devs[i].type +
                     " conn=" + devs[i].connected + " nm=" + devs[i].nmManaged + "]"
            console.log("[NetworkService] devices now " + devs.length + ":" + s +
                        " → type=" + connectionType + " ssid=" + ssid + " sig=" + signalStrength)
        }
    }
    Connections {
        target: root.wifiDev ? root.wifiDev.networks : null
        function onValuesChanged() { root._collectWifi() }
    }

    // Fires only while a scanner lease is on — settles and hotplug visible.
    onWifiNetworksChanged: console.log("[NetworkService] wifi now " + wifiNetworks.length)

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
            security: (isWifi && n) ? _secString(n.security) : "",
            wifiEnabled: Networking.wifiEnabled
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
                inUse: n.connected, known: n.known === true, chan: "", bssid: "", band: ""
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
        // scan settles) would otherwise churn the rows constantly, killing
        // clicks mid-press and the inline password editor.
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
                x.known !== y.known ||
                x.chan !== y.chan || x.bssid !== y.bssid) return false
        }
        return true
    }

    // -------------------------------------------------------------------------
    // LINK PROBE — one gated fork per sweep for everything the native models
    // don't expose: route (src + via gateway), device details (HWADDR, SPEED,
    // IP4 address/subnet, DNS), and the wifi radio state.
    // -------------------------------------------------------------------------
    BoundedProcess {   // bounded: one-shot link probe (P8.1)
        id: linkProbe
        onDone: function (out) { root._absorbLinkProbe(out) }
    }

    function _sampleLink() {
        if (linkProbe.running) return
        var iface = connectionStatus.iface || "any"
        linkProbe.command = ["sh", "-c",
            "ip -4 route get 1 2>/dev/null;" +
            "nmcli device show " + iface + " 2>/dev/null;" +
            "nmcli radio wifi 2>/dev/null"]
        linkProbe.run()
    }

    function _absorbLinkProbe(out) {
        var patch = {}
        var lines = out.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var L = lines[i], m
            if ((m = L.match(/IP4\.ADDRESS\[\d+\]:\s*([\d.]+)\/(\d+)/))) { patch.ip = m[1]; patch.subnet = "/" + m[2] }
            else if ((m = L.match(/IP6\.ADDRESS\[\d+\]:\s*(\S+)/)) && !patch.ip6) patch.ip6 = m[1].split("/")[0]
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

    BoundedProcess {   // bounded: one-shot wifi-list enrichment probe (P8.1)
        id: enrichProc
        onDone: function (out) { root._absorbEnrich(out) }
    }

    function _sampleEnrich() {
        if (enrichProc.running) return
        var now = Date.now()
        if (now - root._lastEnrich < 20000) return
        root._lastEnrich = now
        enrichProc.command = ["sh", "-c",
            "nmcli -t -f SSID,BSSID,CHAN,FREQ,SIGNAL,SECURITY device wifi list 2>/dev/null"]
        enrichProc.run()
    }

    // Enrichment cache (ssid → {bssid, chan, band}) — merged into every row
    // _collectWifi builds, so the native resync can never wipe it (that was
    // producing a wipe/re-add churn every sweep).
    property var _enrichBySsid: ({})

    function _absorbEnrich(out) {
        // Parsing lives in lib/netparse.mjs (node-tested; the \: escape
        // handling is encoded in netparse.test.mjs, not re-derived here).
        var bySsid = Netparse.parseWifiEnrich(out)
        root._enrichBySsid = bySsid
        _collectWifi()                               // single merge path (no-churn)
        var active = bySsid[connectionStatus.ssid]
        if (active && connectionStatus.band !== active.band) _setStatus({ band: active.band })
    }

    // -------------------------------------------------------------------------
    // WIFI RADIO — one native write (NM signal confirms; no fork).
    // -------------------------------------------------------------------------
    property bool wifiRadio: Networking.wifiEnabled
    function toggleRadio() { toggleWifi() }
    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled
        console.log("[NetworkService] wifi radio " + (Networking.wifiEnabled ? "on" : "off"))
    }

    // -------------------------------------------------------------------------
    // SWEEP — 3s while the NETWORK section is on screen: native resync (zero
    // forks; catches per-device/network property drift between model signals)
    // + the one gated IPv4 probe + AP enrichment.
    // -------------------------------------------------------------------------
    Timer {
        interval: 3000
        running: root.sectionLease
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
    // VPN / WIREGUARD — read-only card row (P4.1). One bounded probe over the
    // ACTIVE connections; first vpn/wireguard type wins. Terse -t output
    // escapes ':' inside NAME as '\:' — the tail fields (TYPE, DEVICE) never
    // contain a colon, so read the type as the second-to-last split piece.
    // -------------------------------------------------------------------------
    property var vpnStatus: ({ active: false, name: "", type: "" })

    BoundedProcess {
        id: vpnProbe
        timeoutMs: 8000
        onDone: function(out) {
            var hit = null
            var lines = out.split("\n")
            for (var i = 0; i < lines.length; i++) {
                var f = lines[i].split(":")
                if (f.length < 2) continue
                var type = f[f.length - 2]
                if (type === "vpn" || type === "wireguard") {
                    hit = { active: true, name: f.slice(0, f.length - 2).join(":")
                            .replace(/\\:/g, ":"), type: type }
                    break
                }
            }
            root.vpnStatus = hit || { active: false, name: "", type: "" }
        }
    }

    function _sampleVpn() {
        vpnProbe.command = ["sh", "-c",
            "nmcli -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null"]
        vpnProbe.run()
    }

    Timer {
        interval: 10000
        repeat: true
        running: root.popupOpen && root.isConnected
        onTriggered: { root._sampleVpn(); root._sampleLink() }
    }

    // -------------------------------------------------------------------------
    // SCAN — one bounded nmcli rescan to force fresh results NOW, then collect
    // from the native model after the kernel settles.
    // -------------------------------------------------------------------------
    BoundedProcess {   // bounded: one-shot nmcli rescan trigger (P8.1)
        id: rescanProc
        onDone: function (out) { rescanSettleTimer.restart() }
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
                console.log("[NetworkService] scan timed out")
                root._collectWifi()
            }
        }
    }

    function scanWifi() {
        if (root.scanning) return   // silent — button already disabled in UI
        root.scanning = true
        console.log("[NetworkService] scanning wifi...")
        rescanProc.run()
        scanTimeoutTimer.restart()
    }

    function refreshList(fromScan) { root._collectWifi() }

    // -------------------------------------------------------------------------
    // ENGINEER PANEL — link/PHY, full addressing, routes, counters, hosts
    // (network-engineer section data; one aggregated section-gated probe)
    // -------------------------------------------------------------------------
    property var engLink: ({})      // {channel, freqMhz, signalDbm, chains, signalAvgDbm,
                                    //  beaconAvgDbm, txBitrate, txMcs, rxBitrate, regDomain}
    property var engAddr: ({})      // {v4: [], v6: [], dnsServers: [], dnsDomain: "",
                                    //  dhcpServer: "", leaseHours: 0}
    property var ifaceStats: ({})   // {mtu, rxBytes, rxErrors, rxDropped, txBytes, txErrors, txDropped}
    property var engRoutes: []      // [{dst, via, dev, metric, proto}]
    property var engNeighbors: []   // [{ip, mac, dev}]
    property var engListeners: []   // [{proto, local}]
    property real engRefreshedAt: 0

    property bool _engBusy: false

    BoundedProcess {   // bounded: section-gated engineer probe bundle (P8.1)
        id: engProbe
        onDone: function (out) {
            root._absorbEngineer(out)
            root._engBusy = false
        }
    }

    function sampleEngineer() {
        if (root._engBusy || !root.sectionLease) return
        var iface = root.connectionStatus.iface || ""
        if (iface === "") return
        root._engBusy = true
        engProbe.command = ["sh", "-c",
            "echo ==IW; iw dev " + iface + " link 2>/dev/null" +
            "; echo ==STATION; iw dev " + iface + " station dump 2>/dev/null" +
            "; echo ==REG; iw reg get 2>/dev/null | head -1" +
            "; echo ==ADDR; ip -j addr show dev " + iface + " 2>/dev/null" +
            "; echo ==ROUTE; ip -j route 2>/dev/null" +
            "; echo ==STATS; ip -j -s link show dev " + iface + " 2>/dev/null" +
            "; echo ==NEIGH; ip -j neigh 2>/dev/null" +
            "; echo ==RESOLVE; resolvectl status " + iface + " 2>/dev/null" +
            "; echo ==DHCP; nmcli -t -f DHCP4.OPTION device show " + iface + " 2>/dev/null" +
            "; echo ==LISTEN; ss -H -tuln 2>/dev/null"]
        engProbe.run()
    }

    Timer {
        interval: 15000
        running: root.sectionLease
        repeat: true
        onTriggered: root.sampleEngineer()
    }

    function _absorbEngineer(out) {
        // (I8: parsing in lib/netengineer.mjs — iw/ip -json/resolvectl/
        // dhcpcd/ss sections, node-tested. routes/ifaceStats/listeners/
        // neighbors arrive only when their section did — absent = keep the
        // previous value, exactly the old section guards.)
        var p = NetEng.parseEngineer(out)
        root.engLink = p.link
        root.engAddr = p.addr
        if (p.routes !== undefined) root.engRoutes = p.routes
        if (p.ifaceStats !== undefined) root.ifaceStats = p.ifaceStats
        if (p.neighbors !== undefined) root.engNeighbors = p.neighbors
        if (p.listeners !== undefined) root.engListeners = p.listeners
        root.engRefreshedAt = Date.now()
    }

    function refreshStatus() {
        root._syncNativeStatus()
        root._collectWifi()
        root._sampleLink()
        root.detectDns()
        root.sampleEngineer()
    }

    // -------------------------------------------------------------------------
    // CONNECT / DISCONNECT — nmcli (error taxonomy + saved profiles; the PSK
    // travels over stdin, never argv — argv is world-readable in /proc).
    // -------------------------------------------------------------------------
    Process {   // unbounded-ok: PSK travels over stdin (never argv) and
                // BoundedProcess exposes no stdin — the secret path stays here
        id: connectProc
        property string lastSsid: ""
        property string buffer: ""
        property string pendingSecret: ""
        stdinEnabled: true
        stdout: SplitParser { onRead: function(data) { connectProc.buffer += data + "\n" } }
        stderr: SplitParser { onRead: function(data) { connectProc.buffer += data + "\n" } }
        onStarted: {
            if (pendingSecret !== "") {
                write(pendingSecret + "\n")
                pendingSecret = ""
            }
        }
        onExited: function(code) {
            if (code === 0) {
                console.log("[NetworkService] connected to " + connectProc.lastSsid)
                root.refreshStatus()
            } else {
                var r = ConnectModel.connectFailureReason(connectProc.buffer)
                root.lastConnectError = r.label
                console.log("[NetworkService] connect failed: " + r.label)
                root.connectFailed(connectProc.lastSsid, r.key, r.label)
            }
            root.connectingTo = ""          // clear connecting state (success or failure)
            connectProc.buffer = ""
        }
    }

    function connectWifi(ssid, password) {
        if (!ssid || ssid.length === 0) {
            console.log("[NetworkService] error: no ssid given")
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
        console.log("[NetworkService] connecting to " + ssid + "...")
    }

    BoundedProcess {   // bounded: one-shot nmcli disconnect (P8.1)
        id: disconnectProc
        onDone: function (out, err, code) {
            if (code === 0) console.log("[NetworkService] disconnected")
            else console.log("[NetworkService] disconnect failed (exit " + code + "): " + (out + err).trim())
            root.refreshStatus()
        }
    }

    function disconnectWifi() {
        var iface = root.connectionStatus.iface
        if (!iface || iface.length === 0) {
            console.log("[NetworkService] error: no active interface")
            return
        }
        disconnectProc.command = ["nmcli", "device", "disconnect", iface]
        disconnectProc.run()
    }

    // -------------------------------------------------------------------------
    // HELPERS
    // -------------------------------------------------------------------------

    // Reassign the whole object so change signals fire (nested-var gotcha).
    function _setStatus(patch) {
        root.connectionStatus = Object.assign({}, root.connectionStatus, patch)
    }

    // -------------------------------------------------------------------------
    // DNS PROVIDER — DHCP | Cloudflare | Google | Custom (nmcli con mod).
    // Reads the ACTIVE wifi profile (name ≠ ssid sometimes) and its current
    // ipv4.dns / ignore-auto-dns to derive the mode shown by the segmented UI.
    // -------------------------------------------------------------------------
    property string activeConn: ""      // nmcli profile name of the active wifi
    property string dnsMode: "dhcp"     // dhcp | cloudflare | google | custom
    property string customDns: ""       // user-entered servers (custom mode)
    property bool dnsBusy: false
    property string dnsResult: ""       // inline feedback ("applied · reconnected")
    property real _lastDnsDetect: 0     // epoch s — the probe is 2 forks; rate-limit

    property var _dnsDetectProc: BoundedProcess {   // bounded: one-shot active-profile detect (P8.1)
        command: []
        onDone: function (out) {
            root.dnsBusy = false
            var name = "", lines = out.split("\n")
            for (var i = 0; i < lines.length; i++) {
                var f = lines[i].split(":")
                if (f.length >= 3 && f[1].indexOf("wireless") !== -1 && f[2] === connectionStatus.iface) {
                    name = lines[i].substring(0, lines[i].lastIndexOf(":" + f[1] + ":" + f[2])).trim()
                    break
                }
            }
            root.activeConn = name
            if (name === "") { root.dnsMode = "dhcp"; return }
            var rd = _dnsReadProc
            rd.onDone = function (dnsOut) {
                var parts = dnsOut.split("--\n")
                var dnsLine = (parts[0] || "").trim(), ign = (parts[1] || "").trim()
                var mode = "custom", servers = dnsLine.split(",").filter(function(s){return s !== ""})
                if (ign !== "yes" || servers.length === 0) mode = "dhcp"
                else if (dnsLine.indexOf("1.1.1.1") !== -1) mode = "cloudflare"
                else if (dnsLine.indexOf("8.8.8.8") !== -1) mode = "google"
                root.dnsMode = mode
            }
            rd.command = ["sh", "-c",
                "nmcli -g ipv4.dns connection show '" + name + "' 2>/dev/null; echo '--'; " +
                "nmcli -g ipv4.ignore-auto-dns connection show '" + name + "' 2>/dev/null"]
            rd.run()
        }
    }

    property var _dnsReadProc: BoundedProcess {   // bounded: one-shot profile dns read (P8.1)
        command: []
        onDone: null   // injected by _dnsDetectProc's completion
    }

    function detectDns() {
        var now = new Date().getTime() / 1000
        if (dnsBusy || now - _lastDnsDetect < 8) return
        _lastDnsDetect = now
        if (!connectionStatus.connected || connectionStatus.iface === "") return
        dnsBusy = true
        _dnsDetectProc.buffer = ""
        _dnsDetectProc.command = ["sh", "-c",
            "nmcli -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null"]
        _dnsDetectProc.run()
    }

    function applyDns(mode, custom) {
        if (dnsBusy || activeConn === "") return
        dnsBusy = true
        dnsMode = mode
        if (mode === "custom") customDns = (custom || "").trim()
        var dns = mode === "cloudflare" ? "1.1.1.1 1.0.0.1"
                : mode === "google"     ? "8.8.8.8 8.8.4.4"
                : mode === "custom"     ? customDns : ""
        var ign = mode === "dhcp" ? "no" : "yes"
        if (mode === "custom" && dns === "") { dnsBusy = false; dnsResult = "enter servers first"; return }
        dnsResult = "applying…"
        _dnsApplyProc.command = ["sh", "-c",
            "nmcli connection mod '" + activeConn + "' ipv4.dns '" + dns + "' ipv4.ignore-auto-dns " + ign + " && " +
            "nmcli connection up '" + activeConn + "' >/dev/null 2>&1 && echo APPLIED || echo FAILED"]
        _dnsApplyProc.run()
    }

    property var _dnsApplyProc: BoundedProcess {   // bounded: one-shot nmcli con mod + reconnect (P8.1)
        timeoutMs: 30000            // `nmcli connection up` reconnects the wifi
        command: []
        onDone: function (out) {
            root.dnsBusy = false
            root.dnsResult = out.indexOf("APPLIED") !== -1 ? "applied · reconnected"
                                                           : "apply failed (see journal)"
            root._lastDnsDetect = 0
            root._sampleLink()
        }
    }

    // =========================================================================
    // POPUP DIAGNOSTICS — one-shot IP probe, fetched on open
    // =========================================================================
    BoundedProcess {
        id: ipProc
        command: ["sh", "-c", "ip -4 route get 1 2>/dev/null | grep -oE 'src [0-9.]+' | awk '{print $2}'"]
        onDone: function(out) {
            var ip = out.trim()
            if (ip !== "") root.ipAddress = ip
        }
    }

    function getIP() { ipProc.run() }

    // ── Popup gating ─────────────────────────────────────────────────────────
    // Set by TrayCard.onActiveTrayChanged. Detail data is fetched exactly when
    // visible (Omarchy rule); the bar icon needs none of it anymore.
    property bool popupOpen: false

    onPopupOpenChanged: {
        if (!popupOpen) {
            // Drop the throughput baselines so reopening can't compute a rate
            // across the closed gap (Omarchy: reset history on close).
            root._stats = null
            root.rxRate = ""
            root.txRate = ""
            root.rxTotal = ""
            root.txTotal = ""
            // The speed test is panel-gated: closing aborts mid-flight.
            root.cancelSpeedTest()
            return
        }
        // Fetch-on-open: no waiting for the next timer tick.
        if (isConnected) getIP()
        if (isConnected) root._sampleCounters()
        root._sampleVpn()
        if (isConnected) root._sampleLink()     // gateway/dns/speed/ip6 for the card's LINK rows
        if (isConnected) root._sampleEnrich()   // band/channel (rate-limited to 20s internally)
        root.refreshLastTest()
    }

    // ── Panel-gated speed test (C3) ───────────────────────────────────────
    // Mechanism adapted from qsbar's CloudflareSpeedTest.qml (MIT, upstream
    // Ryoku): plain XHR against speed.cloudflare.com — no process, no daemon.
    // Compact ladder for a popup row: 2×5 MB downloads + 2×1 MB uploads,
    // median reported. The generation counter invalidates every in-flight
    // callback of a cancelled/finished run (qsbar's runGeneration guard).
    property string speedPhase: "idle"     // idle|download|upload|done|error|cancelled
    property real speedDownMbps: 0
    property real speedUpMbps: 0
    property int _speedGen: 0
    property var _speedXhr: null

    function runSpeedTest() {
        if (speedPhase === "download" || speedPhase === "upload") return
        if (!isConnected) return
        root._speedGen++
        var gen = root._speedGen
        speedDownMbps = 0
        speedUpMbps = 0
        speedPhase = "download"
        root._speedLadder(gen, "GET",
            "https://speed.cloudflare.com/__down?bytes=5000000", null, true, [],
            function(samples) {
                if (gen !== root._speedGen) return
                speedDownMbps = Model.median(samples)
                speedPhase = "upload"
                var up = "0".repeat(1000000)
                root._speedLadder(gen, "POST",
                    "https://speed.cloudflare.com/__up", up, false, [],
                    function(upSamples) {
                        if (gen !== root._speedGen) return
                        speedUpMbps = Model.median(upSamples)
                        speedPhase = "done"
                    })
            })
    }

    // Kept for the old settings-side name — same process now, no qs fork.
    function runSpeedTestInBar() { runSpeedTest() }

    // Run `repeats+1` requests, collecting Mbps samples, then onSuccess.
    function _speedLadder(gen, method, url, body, binary, samples, onSuccess) {
        if (gen !== root._speedGen) return
        var xhr = new XMLHttpRequest()
        var headersAt = 0
        var startedAt = 0
        root._speedXhr = xhr
        xhr.onreadystatechange = function() {
            if (gen !== root._speedGen) return
            if (xhr.readyState === XMLHttpRequest.HEADERS_RECEIVED && headersAt === 0)
                headersAt = Date.now()
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            root._speedXhr = null
            speedReaper.stop()
            if (xhr.status !== 200 || (method !== "POST" && headersAt === 0)) {
                speedPhase = "error"
                return
            }
            var bytes = binary && xhr.response ? (xhr.response.byteLength || 0) : (body ? body.length : 0)
            // Qt fires HEADERS_RECEIVED only once the request body is fully
            // written, so for a POST that stamp times the (tiny) response —
            // ~0ms on a fast link → Infinity (H1: the upload leg always
            // measured the wrong window). send→DONE is the honest POST clock.
            var transferMs = Date.now() - (method === "POST" ? startedAt : headersAt)
            var mbps = bytes * 8 / transferMs / 1000
            if (!(bytes > 0) || !(transferMs > 0) || !isFinite(mbps) || mbps <= 0) {
                speedPhase = "error"
                return
            }
            samples.push(mbps)
            if (samples.length < 2) {
                root._speedLadder(gen, method, url, body, binary, samples, onSuccess)
            } else {
                onSuccess(samples)
            }
        }
        xhr.open(method, url, true)
        if (binary) xhr.responseType = "arraybuffer"
        if (method === "POST") xhr.setRequestHeader("Content-Type", "application/octet-stream")
        startedAt = Date.now()
        xhr.send(body)
        // Per-request reaper (qsbar's requestTimer): a stalled probe ends the
        // run instead of pinning "testing…" forever. The callback rides a
        // root property — signal handlers are never assigned from JS here.
        root._speedReap = function() {
            if (gen !== root._speedGen) return
            if (speedPhase !== "download" && speedPhase !== "upload") return
            if (root._speedXhr) root._speedXhr.abort()
            root._speedXhr = null
            speedPhase = "error"
        }
        speedReaper.restart()
    }

    function cancelSpeedTest() {
        if (speedPhase !== "download" && speedPhase !== "upload") return
        root._speedGen++
        if (root._speedXhr) { root._speedXhr.abort(); root._speedXhr = null }
        speedPhase = "cancelled"
    }

    property var _speedReap: null
    Timer {
        id: speedReaper
        interval: 10000
        running: false
        repeat: false
        onTriggered: if (root._speedReap) root._speedReap()
    }

    // ── Last-result persistence + read-back ──────────────────────────────
    // A completed run lands atomically (tmp+mv) in the state home; the same
    // service reads it back (read-only FileView, timer-driven reload — a
    // rename never fires watchChanges) for the "last test" line. This
    // singleton is the speed test's only runner AND its single reader.
    readonly property string _stateDir:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") || "~") + "/.local/state")
        + "/velocity"
    onSpeedPhaseChanged: if (speedPhase === "done") _persistSpeedTest()

    BoundedProcess {
        id: speedtestWriter
    }
    function _persistSpeedTest() {
        var payload = JSON.stringify({
            schema: 1, ts: Date.now(),
            downMbps: Math.round(speedDownMbps * 10) / 10,
            upMbps: Math.round(speedUpMbps * 10) / 10,
            iface: iface, ssid: ssid
        })
        // positional argv ($1 dir, $2 payload) — the T23a "$0" lesson
        speedtestWriter.command = ["sh", "-c",
            "mkdir -p -- \"$1\" && printf '%s' \"$2\" > \"$1/speedtest.json.tmp\" && mv -f \"$1/speedtest.json.tmp\" \"$1/speedtest.json\"",
            "sh", root._stateDir, payload]
        speedtestWriter.run()
    }

    readonly property string lastTestPath: root._stateDir + "/speedtest.json"
    property var lastTest: null          // {schema,ts,downMbps,upMbps,iface,ssid} | null
    FileView {
        id: lastTestFile
        path: root.lastTestPath
        watchChanges: false
        printErrors: false
        onTextChanged: root._ingestLastTest(text())
    }
    function _ingestLastTest(raw) {
        var v = null
        try { v = JSON.parse(raw) } catch (e) { v = null }
        v = (v && typeof v.ts === "number" && typeof v.downMbps === "number") ? v : null
        // Same ts → keep the old object identity (polling re-ingests must not
        // churn every lastTest binding).
        if (v && root.lastTest && root.lastTest.ts === v.ts) return
        root.lastTest = v
    }
    function refreshLastTest() { lastTestFile.reload() }

    // 2s poll while the dashboard shows the speed line (ASYNC reload; the
    // parse lands in onTextChanged above).
    Timer {
        interval: 2000
        running: root.dashboardLease
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshLastTest()
    }

    // -------------------------------------------------------------------------
    // WI-FI QR — payload WIFI:T:…;S:…;P:…; → qrencode ASCII → 0/1 matrix rows.
    // Ported from the (removed) nikos.wifiqr plugin so the network popup can show the
    // share code without opening any external panel.
    // -------------------------------------------------------------------------
    property var qrMatrix: []           // array of "0101…" strings
    property string qrSsid: ""
    property string qrSecurity: ""
    property string qrPassword: ""
    property string qrError: ""

    function generateQr() {
        _qrProc.buffer = ""
        _qrProc.command = ["bash", "-c",
            "iface=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i==\"dev\"){print $(i+1);exit}}'); " +
            "[ -z \"$iface\" ] && iface=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | awk -F: '$2==\"wifi\" && $3 ~ /^connected/{print $1;exit}'); " +
            "[ -z \"$iface\" ] && echo 'No active Wi-Fi connection' && exit 0; " +
            "uuid=$(nmcli --get-values GENERAL.CON-UUID device show \"$iface\" | head -n1); " +
            "mapfile -t fl < <(nmcli --show-secrets --escape no --get-values " +
            "802-11-wireless.ssid,802-11-wireless-security.key-mgmt,802-11-wireless-security.psk connection show uuid \"$uuid\"); " +
            "ssid=${fl[0]}; km=${fl[1]}; pw=${fl[2]}; " +
            "[ -z \"$ssid\" ] && echo 'Could not read the Wi-Fi name' && exit 0; " +
            "sec=nopass; [ -n \"$km\" ] && [ \"$km\" != none ] && sec=WPA; " +
            "printf 'meta\\t%s\\t%s\\t%s\\n' \"$sec\" \"$ssid\" \"$pw\"; " +
            "payload=\"WIFI:T:$sec;S:$ssid;P:$pw;\"; " +
            "qrencode --type ASCII --margin 4 --output - <<< \"$payload\" | " +
            "awk '{r=\"\";for(c=1;c<=length($0);c+=2) r =r (substr($0,c,2) ~ /#/ ? 1 : 0); print r}'"]
        _qrProc.run()
    }

    property var _qrProc: BoundedProcess {   // bounded: one-shot QR matrix generation (P8.1)
        command: []
        onDone: function (out) {
            var raw = out
            root.qrMatrix = []
            root.qrSsid = ""; root.qrSecurity = ""; root.qrPassword = ""
            if (raw.indexOf("No active Wi-Fi") !== -1 || raw.trim() === "") {
                root.qrError = raw.trim() !== "" ? raw.trim().split("\n")[0] : "no active wi-fi"
                return
            }
            var rows = []
            raw.split("\n").forEach(function(line) {
                if (line.indexOf("meta\t") === 0) {
                    var f = line.split("\t")
                    root.qrSecurity = f[1] || ""; root.qrSsid = f[2] || ""; root.qrPassword = f[3] || ""
                } else if (line !== "") rows.push(line)
            })
            root.qrMatrix = rows
            root.qrError = rows.length === 0 ? "could not generate QR" : ""
        }
    }

    function _reset() {
        root.ipAddress = ""
        root.rxRate = ""
        root.txRate = ""
        root.rxTotal = ""
        root.txTotal = ""
        root._stats = null
        root.trafficRxKB = 0
        root.trafficTxKB = 0
        root._lastRxBytes = -1
        root._lastTxBytes = -1
        root._lastTrafficTick = 0
    }
}
