/** Version: 13 — native Quickshell.Bluetooth (BlueZ over DBus) for STATE,
 ** serialized bluetoothctl queue for ACTIONS. P2.2: this is the ONE bluetooth
 ** service — the settings dashboard's device list reads the same instance
 ** through HostBridge (the old BluetoothControlService is gone). **/
pragma Singleton
import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io

Item {
    id: root
    visible: false

    // =========================================================================
    // NATIVE STATE — event-driven BlueZ client
    // =========================================================================
    // Replaces any polling: power and per-device disconnect are single
    // property writes, confirmed by the BlueZ events they trigger; the device
    // model rebuilds on the list's valuesChanged plus per-device Connections
    // (a member's property flip fires ITS notify, not the list's — H9: no
    // rebuild timer).

    readonly property var adapter: Bluetooth.defaultAdapter   // null = no BT

    property bool hasBluetooth: adapter !== null
    property bool powered: adapter !== null && adapter.enabled

    function togglePower() {
        if (adapter) adapter.enabled = !adapter.enabled
    }

    // Adapter identity (address/alias/version/class — static per boot) comes
    // from ONE `bluetoothctl show` at construction: the native adapter object
    // exposes no address/version. Drives the settings status card.
    property string adapterAddress: ""
    property string adapterAlias: ""
    property string adapterVersion: ""
    property string adapterClass: ""

    // ── DEVICE ROWS ─────────────────────────────────────────────────────────
    // `devices` is the FULL registry union (settings list): primitive rows
    //   { mac, name, alias, icon, connected, paired, trusted, battery(-1),
    //     rssi(0-100, 0=unknown) }
    // — never QObjects (dangling C++ refs in delegates are a documented
    // segfault class). Registry enumeration is async; the per-device watchers
    // re-collect on every property flip.
    //
    // RSSI is NOT in the native model — it only streams from a live scan
    // (`[CHG] Device <mac> RSSI: -XX`). scanDevices() captures it into
    // _scanCache (dBm→0-100 quality) and _rebuildDevices() merges it in;
    // scan-only macs become paired:false beacons.
    property var devices: []
    property bool scanning: false
    property string pairingTo: ""     // mac currently being paired; "" = idle
    property string connectingTo: ""  // mac currently being connected; "" = idle
    property int scanSecondsLeft: 0   // counts down while scanning

    property int deviceCount: {
        const devs = Bluetooth.devices.values || []
        let n = 0
        for (let i = 0; i < devs.length; i++) if (devs[i].connected) n++
        return n
    }

    // Battery percentage per MAC, straight from the device objects (the old
    // per-device `bluetoothctl info` sweep is gone).
    readonly property var deviceBatteries: {
        const devs = Bluetooth.devices.values || []
        const map = {}
        for (let i = 0; i < devs.length; i++) {
            const d = devs[i]
            if (d.connected && d.batteryAvailable)
                map[d.address] = Math.round(d.battery * 100)   // 0..1 → percent
        }
        return map
    }

    function disconnectDevice(address) {
        const devs = Bluetooth.devices.values || []
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].address === address) {
                devs[i].connected = false   // writable prop → BlueZ disconnect
                return
            }
        }
    }

    // Connected rows — primitive {address, name, icon} for the bar popup.
    function _glyphFor(icon) {
        var s = String(icon || "")
        if (/mouse/.test(s))        return "󰍦"
        if (/keyboard/.test(s))     return "󰌌"
        if (/headset|headphone|audio/.test(s)) return "󰟎"
        if (/phone/.test(s))        return "󰄜"
        if (/input/.test(s))        return "󰌶"
        return "󰂱"
    }

    function _rowFor(d) {
        return { address: d.address, name: d.name, icon: _glyphFor(d.icon) }
    }

    readonly property var connectedDevices: {
        const devs = Bluetooth.devices.values || []
        const rows = []
        for (let i = 0; i < devs.length; i++)
            if (devs[i].connected) rows.push(_rowFor(devs[i]))
        return rows
    }

    // Kept for API compatibility: TrayCard still sets it, but state is
    // event-driven now — there is nothing to poll-gate anymore.
    property bool popupOpen: false

    // =========================================================================
    // DEVICE MODEL → `devices` (native model ∪ _scanCache)
    // =========================================================================

    // _scanCache: mac -> { name, rssi(0-100) } discovered during the last scan
    // (in-place mutation is fine; not signal-bound — the view binds `devices`).
    // _parsedDevs: the native-model snapshot; _rebuildDevices() merges it with
    // the scan cache into `devices`, reassigned as a new array so change
    // signals fire (same nested-var rule as NetworkService).
    property var _scanCache: ({})
    property var _parsedDevs: []

    Component.onCompleted: {
        identityProc.running = true
        _resyncDeviceWatches()
        console.log("[BluetoothService] native BlueZ: adapter=" +
            (adapter ? adapter.name : "none") + " powered=" + powered +
            " devices=" + deviceCount)
    }

    // Registry enumeration is async — resync when the model changes, and
    // re-arm the per-device watchers: a member device's PROPERTY flip
    // (connected/battery/trusted/…) fires that device's own NOTIFY signal,
    // not the list's valuesChanged — the list object didn't change. This is
    // what a sweep timer would paper over (H9: no rebuild timer; a native
    // property signal costs nothing while idle).
    Connections {
        target: Bluetooth.devices
        function onValuesChanged() { root._resyncDeviceWatches() }
    }

    property var _watchers: []   // per-device Connections, one per member device

    Component {
        id: deviceWatchComp
        Connections {
            function onConnectedChanged()        { root._collectDevices() }
            function onPairedChanged()           { root._collectDevices() }
            function onTrustedChanged()          { root._collectDevices() }
            function onNameChanged()             { root._collectDevices() }
            function onDeviceNameChanged()       { root._collectDevices() }
            function onIconChanged()             { root._collectDevices() }
            function onBatteryChanged()          { root._collectDevices() }
            function onBatteryAvailableChanged() { root._collectDevices() }
        }
    }

    function _resyncDeviceWatches() {
        for (var i = 0; i < root._watchers.length; i++)
            if (root._watchers[i]) root._watchers[i].destroy()
        root._watchers = []
        root._collectDevices()
        var devs = Bluetooth.devices.values || []
        for (var j = 0; j < devs.length; j++) {
            var w = deviceWatchComp.createObject(root, { target: devs[j] })
            if (w) root._watchers.push(w)
        }
    }

    function refresh() { root._collectDevices() }

    function _collectDevices() {
        const devs = Bluetooth.devices.values || []
        const rows = []
        for (let i = 0; i < devs.length; i++) {
            const d = devs[i]
            rows.push({
                mac: d.address,
                name: d.name || d.deviceName || d.address,
                alias: d.name || d.deviceName || d.address,
                icon: d.icon || "",
                connected: d.connected,
                paired: d.paired,
                trusted: d.trusted,
                battery: d.batteryAvailable ? Math.round(d.battery * 100) : -1,
                rssi: 0
            })
        }
        root._parsedDevs = rows
        root._rebuildDevices()
    }

    // First whitespace-delimited token after "Field:" (adapter Alias/Version/Class).
    function matchField(buffer, field) {
        var m = (buffer || "").match(new RegExp(field + ":\\s*(\\S+)"))
        return m ? m[1] : ""
    }

    // -------------------------------------------------------------------------
    // ADAPTER IDENTITY — one-shot (static per boot; no native address/version)
    // -------------------------------------------------------------------------
    Process {   // unbounded-ok: one-shot local command — timeout migration queued
        id: identityProc
        command: ["bluetoothctl", "show"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { identityProc.buffer += data + "\n" } }
        onRunningChanged: {
            if (!running) {
                var b = identityProc.buffer
                // Controller <addr> (first line) + Alias / Version / Class fields.
                var mAddr = b.match(/Controller\s+([0-9A-Fa-f:]{17})/)
                if (mAddr) root.adapterAddress = mAddr[1]
                root.adapterAlias   = root.matchField(b, "Alias")
                root.adapterVersion = root.matchField(b, "Version")
                root.adapterClass   = root.matchField(b, "Class")
                identityProc.buffer = ""
                console.log("[BluetoothService] adapter=" + (root.adapterAddress || "none") +
                            " powered=" + root.powered + " devices=" + root.devices.length)
            }
        }
    }

    // -------------------------------------------------------------------------
    // SCAN — 30s `bluetoothctl --timeout 30 scan on`, consumed incrementally
    // (P4.2: the card's scan toggle auto-stops after 30 s; cancelable)
    // -------------------------------------------------------------------------
    Process {   // unbounded-ok: one-shot local command — timeout migration queued
        id: scanProc
        command: ["bluetoothctl", "--timeout", "30", "scan", "on"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { scanProc.buffer += data + "\n" } }
        onExited: function(code) {
            // Final parse of whatever arrived since the last tick (catches
            // the last RSSI updates), then the ONE paired/info refresh so
            // beacons + signal are current (O4: ticks don't refresh).
            root._parseScan(scanProc.buffer)
            scanProc.buffer = ""
            root.scanning = false
            root.scanSecondsLeft = 0
            scanCountdown.stop()
            console.log("[BluetoothService] scan complete")
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
                // Consume the scan stream incrementally (O4): the whole
                // buffer was re-parsed every second — O(n²) over the scan —
                // and each refresh() re-snapshotted the native model into a
                // NEW devices array, resetting the list's delegates mid-scan.
                // SplitParser delivers whole lines, so the buffer only grows
                // line-aligned; parse the new tail and rebuild once (beacons
                // + RSSI still show live). The native-model refresh waits
                // for scan end; property flips propagate via the per-device
                // watchers (H9), not this parser.
                root._parseScan(scanProc.buffer)
                scanProc.buffer = ""
                root._rebuildDevices()
            }
        }
    }

    function scanDevices() {
        if (!root.powered) {
            console.log("[BluetoothService] adapter offline — toggle power first")
            return
        }
        if (root.scanning) {
            console.log("[BluetoothService] scan already in progress")
            return
        }
        root._scanCache = ({})   // fresh scan → drop stale beacons
        scanProc.buffer = ""
        root.scanning = true
        root.scanSecondsLeft = 30
        console.log("[BluetoothService] scanning for 30s...")
        scanProc.running = true
        scanCountdown.start()
    }

    // P4.2 card toggle: stop a running scan early (kills the child, settles
    // the model — the same path the natural timeout takes, minus the parse).
    function cancelScan() {
        if (!root.scanning) return
        scanCountdown.stop()
        root.scanSecondsLeft = 0
        scanProc.buffer = ""
        scanProc.running = false     // kills `bluetoothctl --timeout …`
        root.scanning = false
        root._rebuildDevices()
        root.refresh()
        console.log("[BluetoothService] scan cancelled")
    }

    // SCAN STREAM PARSER — populate _scanCache from `bluetoothctl scan on` output
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

    // DEVICE MERGE — union _parsedDevs (paired/info) + _scanCache beacons,
    // overlay rssi, sort connected → paired → rssi-desc, reassign as a new
    // array (so change signals fire — same nested-var rule as NetworkService).
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

    // =========================================================================
    // ACTIONS — serialized queue (`bt <mac>` = pair → trust → connect, in
    // order instead of racing on one Process)
    // =========================================================================
    // Power + disconnect stay NATIVE property writes (togglePower /
    // disconnectDevice above); the queue is for the verbs BlueZ has no
    // property for.

    Process {   // unbounded-ok: one-shot local command — timeout migration queued
        id: actionProc
        property string label: ""
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { actionProc.buffer += data + "\n" } }
        stderr: SplitParser { onRead: function(data) { actionProc.buffer += data + "\n" } }
        onExited: function(code) {
            if (code === 0) console.log("[BluetoothService] " + actionProc.label + " ok")
            else console.log("[BluetoothService] " + actionProc.label +
                             " failed (exit " + code + "): " + actionProc.buffer.trim())
            actionProc.buffer = ""
            root._drainQueue()
        }
    }

    // internal action queue (in-place mutation is fine; not signal-bound)
    property var _queue: []
    property bool _busy: false

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
        console.log("[BluetoothService] pair " + mac)
        root._enqueue("pair", mac)
        root._enqueue("trust", mac)
        root._enqueue("connect", mac)
    }
    function trust(mac)      { root._enqueue("trust", mac) }
    function connect(mac)    { root.connectingTo = mac; root._enqueue("connect", mac) }
    function disconnect(mac) { root._enqueue("disconnect", mac) }
    function remove(mac)     { console.log("[BluetoothService] removing " + mac); root._enqueue("remove", mac) }

    // Registry enumeration is async — settle/hotplug visibility in the journal.
    onAdapterChanged: console.log("[BluetoothService] adapter now: " +
        (adapter ? adapter.name + " enabled=" + adapter.enabled : "none"))
    onDevicesChanged: console.log("[BluetoothService] devices now " +
        devices.length + " connected=" + deviceCount +
        " batteries=" + JSON.stringify(deviceBatteries))
}
