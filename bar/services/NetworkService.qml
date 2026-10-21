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
    property string iface: ""       // active interface, e.g. "wlp10s0"
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

    BoundedProcess {
        id: ipProc
        command: ["sh", "-c", "ip -4 route get 1 2>/dev/null | grep -oE 'src [0-9.]+' | awk '{print $2}'"]
        onDone: function(out) {
            var ip = out.trim()
            if (ip !== "") root.ipAddress = ip
        }
    }

    function getIP() { ipProc.run() }

    // ── Active interface (for the throughput counters): `default … dev <iface>` ──
    BoundedProcess {
        id: gwProc
        command: ["sh", "-c", "ip -4 route show default 2>/dev/null"]
        onDone: function(out) {
            var m = out.trim().match(/dev\s+(\S+)/)
            root.iface = m ? m[1] : ""
            // iface known — start sampling now (avoids reading an empty iface path).
            if (root.popupOpen && root.iface !== "")
                statsProc.run()
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
            root.rxTotal = ""
            root.txTotal = ""
            return
        }
        // Fetch-on-open: no waiting for the next timer tick.
        // NOTE: statsProc is NOT started here — it needs root.iface from
        // gwProc's output. gwProc's onRunningChanged kicks statsProc once
        // iface is known (fixes the empty-iface race that showed no data).
        if (isConnected) getIP()
        if (isConnected) gwProc.run()
    }

    // ── Interface throughput: raw sysfs counters for the active iface ────────
    // (BoundedProcess rejoins lines WITH newlines — the TX/RX incident's
    // glued-counter class is structurally impossible here.)
    BoundedProcess {
        id: statsProc
        command: ["sh", "-c",
            "cat /sys/class/net/" + root.iface + "/statistics/rx_bytes " +
            "    /sys/class/net/" + root.iface + "/statistics/tx_bytes 2>/dev/null"]
        onDone: function(out) {
            var s = Model.parseStats(out)
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

    // 2s while the popup is open — rates want a short window to feel live.
    Timer {
        id: statsTimer
        interval: 2000
        repeat: true
        running: root.hasNetwork && root.popupOpen
        onTriggered: if (root.isConnected && root.iface !== "") statsProc.run()
    }

    // (The old 15s hung-process reaper is gone: every probe is a
    // BoundedProcess now — the timeout IS the reaper, at 5s not 15s.)

    function _reset() {
        root.ipAddress = ""
        root.iface = ""
        root.rxRate = ""
        root.txRate = ""
        root.rxTotal = ""
        root.txTotal = ""
        root._stats = null
    }
}
