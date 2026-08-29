/** Version: 26 — native Quickshell.Networking for bar state (zero forks);
 ** popup diagnostics stay as popup-gated one-shot probes (NetworkModel.js) **/
pragma Singleton
import QtQuick
import Quickshell.Networking
import Quickshell.Io
import "../config" as Config
import "NetworkModel.js" as Model

Item {
    id: root
    visible: false

    // =========================================================================
    // NATIVE STATE — Quickshell.Networking (event-driven NM client)
    // =========================================================================
    // Replaces the 5 s nmcli poll (~12 spawn events/min) and the wifi-radio
    // probes: the bar icon's state (type / SSID / connected / live signal) is
    // pure bindings now. Signal of the CONNECTED network is association data —
    // no scan needed. Popup diagnostics below remain gated one-shots.

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
    // TrayCard popup shows, so the scanner is leased to popupOpen. The bar
    // icon needs neither (isConnected/type only). Null-target-safe.
    Binding {
        target: root.wifiDev
        property: "scannerEnabled"
        value: root.popupOpen
    }

    property bool isConnected: activeDev !== null
    property string connectionType: !activeDev ? ""
        : (activeDev.type === DeviceType.Wifi ? "wifi" : "ethernet")

    // SSID: live from the connected network while the scanner lease is active;
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

    // Wi-Fi radio, straight from NM (writable — toggle is one assignment).
    property bool wifiRadio: Networking.wifiEnabled
    function toggleRadio() { Networking.wifiEnabled = !Networking.wifiEnabled }

    // When the connection drops, clear the popup diagnostics and SSID cache.
    onIsConnectedChanged: if (!isConnected) { root._lastSsid = ""; root._reset() }

    Component.onCompleted: console.log(
        "[NetworkService] native: nm=" + hasNetwork +
        " type=" + connectionType + " ssid=" + ssid +
        " sig=" + signalStrength +
        (activeNet ? " rawSignal=" + activeNet.signalStrength : ""))

    // Registry enumeration is async — log device-set changes (hotplug visible)
    // and each device's parsed state so filter mismatches are diagnosable.
    Connections {
        target: Networking.devices
        function onValuesChanged() {
            const devs = Networking.devices.values || []
            let s = ""
            for (let i = 0; i < devs.length; i++)
                s += " [" + devs[i].name + " t=" + devs[i].type +
                     " conn=" + devs[i].connected + " nm=" + devs[i].nmManaged + "]"
            console.log("[NetworkService] devices now " + devs.length + ":" + s +
                        " → type=" + connectionType + " ssid=" + ssid + " sig=" + signalStrength)
        }
    }

    // ── Link diagnostics for the WiFi popup (all popup-gated) ─────────────
    property string ipAddress: ""
    property string gateway: ""     // default IPv4 gateway, e.g. "10.0.0.1"
    property string iface: ""       // active interface, e.g. "wlp10s0"
    property string dns: ""         // PRIMARY DNS server only
    property real latencyMs: -1     // ping RTT (avg); -1 = no reply

    // ── Interface throughput (popup-only): deltas of sysfs counters; totals
    // are raw since-interface-up. Empty rate strings mean "no sample yet" —
    // the fold in NetworkModel.js guards iface changes and counter resets.
    property string rxRate: ""
    property string txRate: ""
    property string rxTotal: ""
    property string txTotal: ""
    property var _stats: null       // last sample {iface, rx, tx, t}

    // =========================================================================
    // POPUP DIAGNOSTICS — one-shot probes, fetched on open, polled while open
    // =========================================================================

    Process {
        id: ipProc
        command: ["sh", "-c", "ip -4 route get 1 2>/dev/null | grep -oE 'src [0-9.]+' | awk '{print $2}'"]
        stdout: SplitParser {
            onRead: function(data) {
                var ip = data.trim()
                if (ip !== "") root.ipAddress = ip
            }
        }
    }

    function getIP() {
        if (!ipProc.running) ipProc.running = true
    }

    // ── Gateway + active interface: `default via <gw> dev <iface>` ──────────
    Process {
        id: gwProc
        command: ["sh", "-c", "ip -4 route show default 2>/dev/null"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { gwProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                var line = gwProc.buffer.trim()
                gwProc.buffer = ""
                var m = line.match(/via\s+(\S+)\s+dev\s+(\S+)/)
                if (m) { root.gateway = m[1]; root.iface = m[2] }
                else { root.gateway = ""; root.iface = "" }
            }
        }
    }

    // ── PRIMARY DNS only: nmcli terse emits `IP4.DNS[1]:<ip>` ───────────────
    Process {
        id: dnsProc
        command: ["sh", "-c", "nmcli -t -f IP4.DNS dev show 2>/dev/null | grep ':' | head -1"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { dnsProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                var line = dnsProc.buffer.trim()
                dnsProc.buffer = ""
                if (line.indexOf(":") !== -1)
                    root.dns = line.substring(line.indexOf(":") + 1).trim()
                else
                    root.dns = ""
            }
        }
    }

    // ── Latency: one ping to a stable target (1s timeout so it can't hang) ──
    Process {
        id: pingProc
        command: ["sh", "-c", "ping -c 1 -W 1 1.1.1.1 2>/dev/null"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { pingProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                var out = pingProc.buffer
                pingProc.buffer = ""
                var m = out.match(/rtt[^=]*=\s*([0-9.]+)\/([0-9.]+)/)
                root.latencyMs = m ? parseFloat(m[2]) : -1
            }
        }
    }

    // ── Popup gating ─────────────────────────────────────────────────────────
    // Set by TrayCard.onActiveTrayChanged. Detail data is fetched exactly when
    // visible (Omarchy rule); the bar icon needs none of it anymore.
    property bool popupOpen: false

    onPopupOpenChanged: {
        if (!popupOpen) {
            // Drop the throughput baseline so reopening can't compute a rate
            // across the closed gap (Omarchy: reset history on close).
            root._stats = null
            root.rxRate = ""
            root.txRate = ""
            return
        }
        // Fetch-on-open: no waiting for the next timer tick.
        if (isConnected) getIP()
        if (isConnected && !gwProc.running)   gwProc.running = true
        if (isConnected && !dnsProc.running)  dnsProc.running = true
        if (isConnected && !pingProc.running) pingProc.running = true
        if (isConnected && !statsProc.running) statsProc.running = true
    }

    // ── Interface throughput: raw sysfs counters for the active iface ────────
    Process {
        id: statsProc
        command: ["sh", "-c",
            "cat /sys/class/net/" + root.iface + "/statistics/rx_bytes " +
            "    /sys/class/net/" + root.iface + "/statistics/tx_bytes 2>/dev/null"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { statsProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                var s = Model.parseStats(statsProc.buffer)
                statsProc.buffer = ""
                if (s && root.iface) {
                    var r = Model.throughputState(root._stats, root.iface, s.rx, s.tx, Date.now())
                    root.rxRate = r.rxRate
                    root.txRate = r.txRate
                    root.rxTotal = r.rxTotal
                    root.txTotal = r.txTotal
                    root._stats = r.state
                }
            }
        }
    }

    // 2s while the popup is open — rates want a short window to feel live.
    Timer {
        id: statsTimer
        interval: 2000
        repeat: true
        running: root.hasNetwork && root.popupOpen
        onTriggered: if (root.isConnected && !statsProc.running) statsProc.running = true
    }

    // Gateway / DNS / latency refresh — slower cadence (these change rarely
    // and ping is a network round-trip). Popup-only: stops dead while closed.
    Timer {
        id: diagTimer
        interval: 10000
        repeat: true
        triggeredOnStart: true
        running: root.hasNetwork && root.popupOpen
        onTriggered: {
            if (!root.isConnected) return
            if (!gwProc.running)   gwProc.running = true
            if (!dnsProc.running)  dnsProc.running = true
            if (!pingProc.running) pingProc.running = true
        }
    }

    // Hung-process reaper (Omarchy tailscale pattern): every poll is skipped
    // while its own Process is still running, so one that never exits silently
    // stops all refreshing and stays stopped. Sweep anything still running well
    // inside the poll interval so the next tick starts clean.
    Timer {
        id: netWatchdog
        interval: 15000
        repeat: true
        running: true
        onTriggered: {
            if (ipProc.running)     ipProc.running = false
            if (gwProc.running)     gwProc.running = false
            if (dnsProc.running)    dnsProc.running = false
            if (pingProc.running)   pingProc.running = false
            if (statsProc.running)  statsProc.running = false
        }
    }

    function _reset() {
        root.ipAddress = ""
        root.gateway = ""
        root.iface = ""
        root.dns = ""
        root.latencyMs = -1
        root.rxRate = ""
        root.txRate = ""
        root.rxTotal = ""
        root.txTotal = ""
        root._stats = null
    }
}
