// =============================================================================
// BluetoothControlService.qml — bluetoothctl control (power + device mgmt)
// =============================================================================
//
// PROBES (one process each, proven `sh -c` + SplitParser pattern):
//   showProc  bluetoothctl show                              → powered
//   devsProc  bluetoothctl devices + per-device info (batched)
//
// devsProc runs a single `sh -c` for-loop so we get every device's
// Connected/Paired/Trusted/Battery in ONE process (avoids spawning N procs):
//   bluetoothctl devices | while read _ mac rest; do
//       echo MAC=$mac; echo ALIAS=$rest
//       bluetoothctl info $mac | grep -E 'Connected:|Paired:|Trusted:|Battery Percentage:'
//       echo ---
//   done
// Blocks are split on "---" and parsed line-by-line.
//
// RSSI is NOT in `bluetoothctl info` — it only streams from a live scan
// (`[CHG] Device <mac> RSSI: -XX`). scanDevices() captures it into _scanCache
// (dBm→0-100 quality) and _rebuildDevices() merges it into `devices`; scan-only
// macs become paired:false beacons. Paired/connected devices also carry Battery.
// devices entry:
//   { mac, name, alias, icon, connected, paired, trusted, battery(-1=unknown), rssi(0=unknown) }
//
// ACTIONS use a serialized queue (_busy + _queue) so the `bt <mac>` convenience
// verb (pair → trust → connect) runs in order instead of racing on one Process.
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io
import "../config" as Config

Item {
    id: root
    visible: false

    property bool powered: false
    property var devices: []
    property bool scanning: false
    property string pairingTo: ""     // mac currently being paired; "" = idle
    property string connectingTo: ""  // mac currently being connected; "" = idle

    // Adapter identity (from `bluetoothctl show`) — drives the status card.
    property string adapterAddress: ""
    property string adapterAlias: ""
    property string adapterVersion: ""
    property string adapterClass: ""

    // internal action queue (in-place mutation is fine; not signal-bound)
    property var _queue: []
    property bool _busy: false

    // _scanCache: mac -> { name, rssi(0-100) } discovered during the last scan
    // (in-place mutation is fine; not signal-bound — the view binds `devices`).
    // _parsedDevs: the bluetoothctl `devices`+`info` parse (paired/connected/
    // battery/icon). _rebuildDevices() merges both into `devices`, reassigned as
    // a new array so change signals fire (same nested-var rule as NetworkControl).
    property var _scanCache: ({})
    property var _parsedDevs: []

    // -------------------------------------------------------------------------
    // POWER STATE
    // -------------------------------------------------------------------------

    Process {
        id: showProc
        command: ["bluetoothctl", "show"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { showProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                var b = showProc.buffer
                root.powered = b.indexOf("Powered: yes") !== -1
                // Controller <addr> (first line) + Alias / Version / Class fields.
                var mAddr = b.match(/Controller\s+([0-9A-Fa-f:]{17})/)
                if (mAddr) root.adapterAddress = mAddr[1]
                root.adapterAlias   = root.matchField(b, "Alias")
                root.adapterVersion = root.matchField(b, "Version")
                root.adapterClass   = root.matchField(b, "Class")
                showProc.buffer = ""
            }
        }
    }

    // -------------------------------------------------------------------------
    // DEVICE LIST (batched one-shot)
    // -------------------------------------------------------------------------

    Process {
        id: devsProc
        command: ["sh", "-c", "bluetoothctl devices 2>/dev/null | while read -r _ mac rest; do echo \"MAC=$mac\"; echo \"ALIAS=$rest\"; bluetoothctl info \"$mac\" 2>/dev/null | grep -E 'Connected:|Paired:|Trusted:|Battery Percentage:'; echo '---'; done"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { devsProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                root._parsedDevs = root._parseDevices(devsProc.buffer)
                devsProc.buffer = ""
                root._rebuildDevices()
            }
        }
    }

    // -------------------------------------------------------------------------
    // POLLING
    // -------------------------------------------------------------------------

    Timer {
        interval: 5000
        running: Config.SharedState.dashboardVisible  // only when the dashboard is open
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    function refresh() {
        if (!showProc.running) showProc.running = true
        if (!devsProc.running) devsProc.running = true
    }

    // -------------------------------------------------------------------------
    // SCAN
    // -------------------------------------------------------------------------

    property int scanSecondsLeft: 0   // counts down while scanning

    Process {
        id: scanProc
        command: ["bluetoothctl", "--timeout", "8", "scan", "on"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { scanProc.buffer += data } }
        onExited: function(code) {
            // Final parse of the scan stream (catches the last RSSI updates),
            // then a paired/info refresh so beacons + signal are current.
            root._parseScan(scanProc.buffer)
            scanProc.buffer = ""
            root.scanning = false
            root.scanSecondsLeft = 0
            scanCountdown.stop()
            CommandService.pushLog("[bluetooth] scan complete", "output")
            root._rebuildDevices()
            root.refresh()
        }
    }

    Timer {
        id: scanCountdown
        interval: 1000
        repeat: true
        onTriggered: {
            if (root.scanSecondsLeft > 0) {
                root.scanSecondsLeft -= 1
                // Parse the in-flight scan stream so beacons + RSSI appear LIVE,
                // then refresh the paired/info probe too.
                root._parseScan(scanProc.buffer)
                root._rebuildDevices()
                root.refresh()
            }
        }
    }

    function scanDevices() {
        if (!root.powered) {
            CommandService.pushLog("[bluetooth] adapter offline — toggle power first", "warning")
            return
        }
        if (root.scanning) {
            CommandService.pushLog("[bluetooth] scan already in progress", "warning")
            return
        }
        root._scanCache = ({})   // fresh scan → drop stale beacons
        scanProc.buffer = ""
        root.scanning = true
        root.scanSecondsLeft = 8
        CommandService.pushLog("[bluetooth] scanning for 8s...", "output")
        scanProc.running = true
        scanCountdown.start()
    }

    // -------------------------------------------------------------------------
    // POWER TOGGLE
    // -------------------------------------------------------------------------

    Process {
        id: powerProc
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { powerProc.buffer += data } }
        stderr: SplitParser { onRead: function(data) { powerProc.buffer += data } }
        onExited: function(code) {
            powerProc.buffer = ""
            root.refresh()
            CommandService.pushLog("[bluetooth] power " + (root.powered ? "on" : "off"), "output")
        }
    }

    function togglePower() {
        // Coalesce: a rapid double-toggle reassigning command mid-run races
        // the first write; the exit handler refreshes real state anyway.
        if (powerProc.running) return
        powerProc.command = ["bluetoothctl", "power", root.powered ? "off" : "on"]
        powerProc.buffer = ""
        powerProc.running = true
    }

    // -------------------------------------------------------------------------
    // ACTIONS (serialized via queue)
    // -------------------------------------------------------------------------

    Process {
        id: actionProc
        property string label: ""
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { actionProc.buffer += data } }
        stderr: SplitParser { onRead: function(data) { actionProc.buffer += data } }
        onExited: function(code) {
            if (code === 0) CommandService.pushLog("[bluetooth] " + actionProc.label + " ok", "success")
            else CommandService.pushLog("[bluetooth] " + actionProc.label + " failed (exit " + code + "): " + actionProc.buffer.trim(), "error")
            actionProc.buffer = ""
            root._drainQueue()
        }
    }

    function _enqueue(verb, mac) {
        root._queue.push({ verb: verb, mac: mac })
        if (!root._busy) root._drainQueue()
    }

    function _drainQueue() {
        if (root._queue.length === 0) {
            root._busy = false
            root.pairingTo = ""
            root.connectingTo = ""
            root.refresh()
            return
        }
        root._busy = true
        var next = root._queue.shift()
        actionProc.label = next.verb + " " + next.mac
        actionProc.command = ["bluetoothctl", next.verb, next.mac]
        actionProc.buffer = ""
        actionProc.running = true
    }

    function pair(mac) {
        root.pairingTo = mac
        CommandService.pushLog("[bluetooth] pair " + mac, "output")
        root._enqueue("pair", mac)
        root._enqueue("trust", mac)
        root._enqueue("connect", mac)
    }
    function trust(mac)      { root._enqueue("trust", mac) }
    function connect(mac)    { root.connectingTo = mac; root._enqueue("connect", mac) }
    function disconnect(mac) { root._enqueue("disconnect", mac) }
    function remove(mac)     { CommandService.pushLog("[bluetooth] removing " + mac, "output"); root._enqueue("remove", mac) }

    // -------------------------------------------------------------------------
    // PARSER
    // -------------------------------------------------------------------------

    function _parseDevices(raw) {
        var blocks = (raw || "").split("---")
        var devs = []
        for (var i = 0; i < blocks.length; i++) {
            var block = blocks[i].trim()
            if (block.length === 0) continue

            var lines = block.split("\n")
            var d = { mac: "", name: "", alias: "", icon: "", connected: false, paired: false, trusted: false, battery: -1, rssi: 0 }
            for (var j = 0; j < lines.length; j++) {
                var ln = lines[j].trim()
                if (ln.indexOf("MAC=") === 0) {
                    d.mac = ln.substring(4).trim()
                } else if (ln.indexOf("ALIAS=") === 0) {
                    d.name = ln.substring(6).trim()
                    d.alias = d.name
                } else if (ln.indexOf("Connected:") === 0) {
                    d.connected = (ln.split(":")[1].trim() === "yes")
                } else if (ln.indexOf("Paired:") === 0) {
                    d.paired = (ln.split(":")[1].trim() === "yes")
                } else if (ln.indexOf("Trusted:") === 0) {
                    d.trusted = (ln.split(":")[1].trim() === "yes")
                } else if (ln.indexOf("Icon:") === 0) {
                    d.icon = ln.substring(5).trim()    // e.g. "input-mouse"
                } else if (ln.indexOf("Battery Percentage:") === 0) {
                    var m = ln.match(/\((\d+)\)/)
                    if (m) d.battery = parseInt(m[1])
                }
            }
            if (d.mac.length > 0) devs.push(d)
        }
        return devs
    }

    // -------------------------------------------------------------------------
    // SCAN STREAM PARSER — populate _scanCache from `bluetoothctl scan on` output
    // -------------------------------------------------------------------------
    //   [NEW]/[CHG] Device <mac> <name>   → beacon alias
    //   [CHG] Device <mac> RSSI: -XX      → signal quality (0-100)
    // dBm→quality = clamp(2*(dbm+100)): -50→100, -75→50, -100→0.
    function _parseScan(raw) {
        var lines = (raw || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var ln = lines[i]
            if (ln.indexOf("[DEL]") !== -1) continue            // device removed — skip
            var dm = ln.match(/Device\s+([0-9A-Fa-f:]{17})/)
            if (!dm) continue
            var mac = dm[1]
            if (!root._scanCache[mac]) root._scanCache[mac] = { name: "", rssi: 0 }
            var rm = ln.match(/RSSI:\s*(-?\d+)/)
            if (rm) {
                var dbm = parseInt(rm[1])
                var q = 2 * (dbm + 100)
                root._scanCache[mac].rssi = (q < 0) ? 0 : (q > 100 ? 100 : q)
            } else {
                var nm = ln.match(/Device\s+[0-9A-Fa-f:]{17}\s+(.+)$/)
                if (nm && nm[1]) root._scanCache[mac].name = nm[1].trim()
            }
        }
    }

    // -------------------------------------------------------------------------
    // DEVICE MERGE — union _parsedDevs (paired/info) + _scanCache beacons,
    // overlay rssi, sort connected → paired → rssi-desc, reassign as a new array
    // (so change signals fire — same nested-var rule as NetworkControlService).
    // -------------------------------------------------------------------------
    function _rebuildDevices() {
        var byMac = {}
        var order = []
        for (var i = 0; i < root._parsedDevs.length; i++) {
            var d = root._parsedDevs[i]
            byMac[d.mac] = {
                mac: d.mac, name: d.name, alias: d.alias || "", icon: d.icon || "",
                connected: d.connected, paired: d.paired, trusted: d.trusted,
                battery: d.battery, rssi: 0
            }
            order.push(d.mac)
        }
        for (var mac in root._scanCache) {
            if (!Object.prototype.hasOwnProperty.call(root._scanCache, mac)) continue
            var s = root._scanCache[mac]
            if (byMac[mac]) {
                byMac[mac].rssi = s.rssi || 0
                if (s.name && !byMac[mac].name) byMac[mac].name = s.name
            } else {
                byMac[mac] = {
                    mac: mac, name: s.name || mac, alias: "", icon: "",
                    connected: false, paired: false, trusted: false,
                    battery: -1, rssi: s.rssi || 0
                }
                order.push(mac)
            }
        }
        var arr = []
        for (var k = 0; k < order.length; k++) arr.push(byMac[order[k]])
        arr.sort(function(a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1
            if (a.paired !== b.paired)       return a.paired ? -1 : 1
            return b.rssi - a.rssi
        })
        root.devices = arr
    }

    // First whitespace-delimited token after "Field:" (adapter Alias/Version/Class).
    function matchField(buffer, field) {
        var m = (buffer || "").match(new RegExp(field + ":\\s*(\\S+)"))
        return m ? m[1] : ""
    }
}
