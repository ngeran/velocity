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
// RSSI is NOT exposed by `bluetoothctl info` on most bluez builds, so we show
// Battery Percentage instead (more useful). devices entry:
//   { mac, name, connected, paired, trusted, battery(-1=unknown) }
//
// ACTIONS use a serialized queue (_busy + _queue) so the `bt <mac>` convenience
// verb (pair → trust → connect) runs in order instead of racing on one Process.
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false

    property bool powered: false
    property var devices: []
    property bool scanning: false

    // internal action queue (in-place mutation is fine; not signal-bound)
    property var _queue: []
    property bool _busy: false

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
                root.powered = showProc.buffer.indexOf("Powered: yes") !== -1
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
                root.devices = root._parseDevices(devsProc.buffer)
                devsProc.buffer = ""
            }
        }
    }

    // -------------------------------------------------------------------------
    // POLLING
    // -------------------------------------------------------------------------

    Timer {
        interval: 5000
        running: true
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

    Process {
        id: scanProc
        command: ["bluetoothctl", "--timeout", "8", "scan", "on"]
        onExited: function(code) {
            root.scanning = false
            CommandService.pushLog("[bluetooth] scan complete", "output")
            root.refresh()
        }
    }

    function scanDevices() {
        if (!root.powered) {
            CommandService.pushLog("[bluetooth] adapter offline — run 'toggle bt' first", "warning")
            return
        }
        if (root.scanning) {
            CommandService.pushLog("[bluetooth] scan already in progress", "warning")
            return
        }
        root.scanning = true
        CommandService.pushLog("[bluetooth] scanning for 8s...", "output")
        scanProc.running = true
    }

    // -------------------------------------------------------------------------
    // POWER TOGGLE
    // -------------------------------------------------------------------------

    Process {
        id: powerProc
        command: ["bluetoothctl", "power", "toggle"]
        onExited: function(code) {
            root.refresh()
            CommandService.pushLog("[bluetooth] power toggled", "output")
        }
    }

    function togglePower() {
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

    function pair(mac)       { CommandService.pushLog("[bluetooth] pair " + mac, "output");      root._enqueue("pair", mac) }
    function trust(mac)      { root._enqueue("trust", mac) }
    function connect(mac)    { root._enqueue("connect", mac) }
    function disconnect(mac) { root._enqueue("disconnect", mac) }

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
            var d = { mac: "", name: "", connected: false, paired: false, trusted: false, battery: -1 }
            for (var j = 0; j < lines.length; j++) {
                var ln = lines[j].trim()
                if (ln.indexOf("MAC=") === 0) {
                    d.mac = ln.substring(4).trim()
                } else if (ln.indexOf("ALIAS=") === 0) {
                    d.name = ln.substring(6).trim()
                } else if (ln.indexOf("Connected:") === 0) {
                    d.connected = (ln.split(":")[1].trim() === "yes")
                } else if (ln.indexOf("Paired:") === 0) {
                    d.paired = (ln.split(":")[1].trim() === "yes")
                } else if (ln.indexOf("Trusted:") === 0) {
                    d.trusted = (ln.split(":")[1].trim() === "yes")
                } else if (ln.indexOf("Battery Percentage:") === 0) {
                    var m = ln.match(/\((\d+)\)/)
                    if (m) d.battery = parseInt(m[1])
                }
            }
            if (d.mac.length > 0) devs.push(d)
        }
        return devs
    }
}
