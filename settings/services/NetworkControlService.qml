// =============================================================================
// NetworkControlService.qml — nmcli network control (status + wifi management)
// =============================================================================
//
// PROBES (all use the proven `sh -c` + SplitParser + onRunningChanged pattern):
//   linkProbe   (3s)  nmcli -t -f TYPE,STATE,DEVICE,CONNECTION device
//   wifiActive  (4s)  nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi   (active AP)
//   ipProbe     (3s)  ip -4 route get 1                          (IPv4)
//   wifiList    (10s) nmcli -t -f IN-USE,BSSID,SSID,SIGNAL,SECURITY,CHAN dev wifi
//
// connectionStatus is a nested var object → reassigned as a whole (via
// _setStatus) so QML change signals fire (in-place mutation does not).
// wifiNetworks reassigned as a new array for the same reason.
//
// wifiNetworks items: { ssid, signal(0-100), security, inUse, chan, bssid }.
// `connectingTo` holds the SSID mid-connect (drives the row spinner); cleared
// in connectProc.onExited. See _parseWifiList for the BSSID/colon handling.
// =============================================================================

pragma Singleton

import QtQuick
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
    // the row's connecting spinner/tint — was previously read but never set.
    property string connectingTo: ""

    // Last connect failure, classified (key/label from NetworkControlModel).
    // The signal carries the same info for views: WifiListView reopens the
    // passphrase prompt on "wrong-password" (Omarchy reprompt pattern).
    property string lastConnectError: ""
    signal connectFailed(string ssid, string reasonKey, string reasonLabel)

    // -------------------------------------------------------------------------
    // LINK PROBE — type / connected / interface
    // -------------------------------------------------------------------------

    Process {
        id: linkProbe
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE,DEVICE,CONNECTION device | grep -E '^(wifi|ethernet):connected' | head -1"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { linkProbe.buffer += data } }
        onRunningChanged: {
            if (!running) {
                var line = linkProbe.buffer.trim()
                if (line.length > 0) {
                    var parts = line.split(":")
                    root._setStatus({
                        type: parts[0] || "",
                        connected: (parts[1] === "connected"),
                        iface: parts[2] || ""
                    })
                } else {
                    root._setStatus({ type: "", connected: false, iface: "", ssid: "", signal: 0 })
                }
                linkProbe.buffer = ""
            }
        }
    }

    // -------------------------------------------------------------------------
    // ACTIVE WIFI PROBE — SSID + signal of the connected AP
    // -------------------------------------------------------------------------

    Process {
        id: wifiActive
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi | grep '^yes:' | head -1"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { wifiActive.buffer += data } }
        onRunningChanged: {
            if (!running) {
                var line = wifiActive.buffer.trim()
                if (line.length > 0) {
                    var parts = line.split(":")
                    var sig = parseInt(parts[parts.length - 1]) || 0
                    root._setStatus({
                        ssid: parts.slice(1, parts.length - 1).join(":"),
                        signal: sig
                    })
                } else if (root.connectionStatus.type !== "ethernet") {
                    root._setStatus({ ssid: "", signal: 0 })
                }
                wifiActive.buffer = ""
            }
        }
    }

    // -------------------------------------------------------------------------
    // IP PROBE — IPv4 of the default route
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
    // WIFI LIST PROBE — all visible networks
    // -------------------------------------------------------------------------

    Process {
        id: wifiListProc
        command: ["sh", "-c", "nmcli -t -f IN-USE,BSSID,SSID,SIGNAL,SECURITY,CHAN dev wifi 2>/dev/null"]
        property string buffer: ""
        property bool isScanRefresh: false
        stdout: SplitParser {
            onRead: function(data) {
                wifiListProc.buffer += data + "\n"
            }
        }
        onRunningChanged: {
            // Process exited — give SplitParser one event-loop tick to finish
            // delivering any buffered lines before we parse.
            if (!running) wifiParseTimer.restart()
        }
    }

    Timer {
        id: wifiParseTimer
        interval: 50
        repeat: false
        onTriggered: {
            var nets = root._parseWifiList(wifiListProc.buffer)
            root.wifiNetworks = nets
            if (wifiListProc.isScanRefresh) {
                root.scanning = false
                scanTimeoutTimer.stop()
                wifiListProc.isScanRefresh = false
            }
            wifiListProc.buffer = ""
        }
    }

    // -------------------------------------------------------------------------
    // POLLING TIMERS
    // -------------------------------------------------------------------------

    Timer {
        interval: 3000
        // Section-gated: window open AND the network section on screen (the
        // section-change nudge handles instant data on entry).
        running: Config.SharedState.dashboardVisible
              && Config.SharedState.controlSection === "network"
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!linkProbe.running) linkProbe.running = true
            if (!wifiActive.running) wifiActive.running = true
            if (!ipProbe.running) ipProbe.running = true
        }
    }

    Timer {
        interval: 10000
        // The full wifi-list query is the most expensive poll in the process —
        // run it only while the network section is actually on screen.
        running: Config.SharedState.dashboardVisible
              && Config.SharedState.controlSection === "network"
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!wifiListProc.running) wifiListProc.running = true }
    }

    // -------------------------------------------------------------------------
    // SCAN
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
                // Give kernel 2s to populate scan cache, then fetch
                rescanSettleTimer.restart()
            }
        }
    }

    Timer {
        id: rescanSettleTimer
        interval: 2000
        repeat: false
        onTriggered: root.refreshList(true)
    }

    // Safety valve — if rescanProc never fires onRunningChanged, clear spinner
    Timer {
        id: scanTimeoutTimer
        interval: 10000
        repeat: false
        onTriggered: {
            if (root.scanning) {
                root.scanning = false
                CommandService.pushLog("[network] scan timed out", "warning")
                root.refreshList(false)
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

    function refreshList(fromScan) {
        if (!wifiListProc.running) {
            if (fromScan) wifiListProc.isScanRefresh = true
            wifiListProc.running = true
        }
    }

    function refreshStatus() {
        if (!linkProbe.running) linkProbe.running = true
        if (!wifiActive.running) wifiActive.running = true
        if (!ipProbe.running) ipProbe.running = true
    }

    // -------------------------------------------------------------------------
    // CONNECT / DISCONNECT
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
                root.refreshList()
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
    // PARSERS / HELPERS
    // -------------------------------------------------------------------------

    // Reassign the whole object so change signals fire (nested-var gotcha).
    function _setStatus(patch) {
        root.connectionStatus = Object.assign({}, root.connectionStatus, patch)
    }

    // nmcli escapes colons that occur INSIDE a value (BSSID, SSID) as "\:", so
    // only an unescaped ":" is a real field separator. Un-escape to a placeholder,
    // split on ":", then restore — yielding fixed-order fields with no positional
    // guessing: IN-USE, BSSID, SSID, SIGNAL, SECURITY, CHAN.
    function _parseWifiList(raw) {
        var lines = (raw || "").trim().split("\n")
        var best = {}
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line.length === 0) continue

            var parts = line.replace(/\\:/g, "__C__").split(":")
                            .map(function(p) { return p.replace(/__C__/g, ":") })
            if (parts.length < 6) continue

            var inUse    = (parts[0] === "*")
            var bssid    = parts[1]
            var ssid     = parts[2]
            var signal   = parseInt(parts[3]) || 0
            var security = parts[4]
            var chan     = parts[5]

            if (!ssid || ssid === "--") continue   // skip hidden / empty SSIDs

            var existing = best[ssid]
            if (!existing || signal > existing.signal) {
                best[ssid] = {
                    ssid: ssid, signal: signal, security: security,
                    inUse: inUse, chan: chan, bssid: bssid
                }
            } else if (inUse) {
                best[ssid].inUse = true
            }
        }

        var arr = []
        for (var s in best) {
            if (Object.prototype.hasOwnProperty.call(best, s)) arr.push(best[s])
        }
        arr.sort(function(a, b) { return b.signal - a.signal })
        return arr
    }
}
