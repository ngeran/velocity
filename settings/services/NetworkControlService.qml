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

Item {
    id: root
    visible: false

    property var connectionStatus: ({
        type: "",
        connected: false,
        iface: "",
        ssid: "",
        ip: "",
        signal: 0
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
            signal: (isWifi && n) ? Math.round(n.signalStrength * 100) : 0
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
        if (!wifiDev) { root.wifiNetworks = []; return }
        const nets = wifiDev.networks.values || []
        const best = {}
        for (let i = 0; i < nets.length; i++) {
            const n = nets[i]
            const ssid = n.name
            if (!ssid) continue
            const sig = Math.round((n.signalStrength || 0) * 100)
            const row = {
                ssid: ssid, signal: sig, security: _secString(n.security),
                inUse: n.connected, chan: "", bssid: ""
            }
            const existing = best[ssid]
            if (!existing || sig > existing.signal) best[ssid] = row
            else if (row.inUse) best[ssid].inUse = true
        }
        const arr = []
        for (let s in best)
            if (Object.prototype.hasOwnProperty.call(best, s)) arr.push(best[s])
        arr.sort(function(a, b) { return b.signal - a.signal })
        root.wifiNetworks = arr
    }

    // -------------------------------------------------------------------------
    // IPv4 PROBE — not exposed natively; gated one-shot
    // -------------------------------------------------------------------------
    Process {
        id: ipProbe
        command: ["sh", "-c", "ip -4 route get 1 2>/dev/null"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { ipProbe.buffer += data } }
        onRunningChanged: {
            if (!running) {
                var m = ipProbe.buffer.match(/src\s+([\d.]+)/)
                root._setStatus({ ip: m ? m[1] : "" })
                ipProbe.buffer = ""
            }
        }
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
            if (!ipProbe.running) ipProbe.running = true
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
        if (!ipProbe.running) ipProbe.running = true
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
