/** Version: 27 — native Quickshell.Networking for bar state (zero forks);
 ** popup diagnostics stay as popup-gated one-shot probes (NetworkModel.mjs);
 ** H1: glance-only card (scan/join moved to settings), speed results persist **/
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Io
import "../config" as Config
import "NetworkModel.mjs" as Model

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

    // ── Scanned access points ─────────────────────────────────────────────
    // (H1: the raw scan list `aps` moved out — the bar card is glance-only
    // now; the settings app owns scanning and joining. The scanner LEASE
    // stays: device.networks (→ activeNet → live ssid/signal for the hero)
    // only exists while it runs.)

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
    // the fold in NetworkModel.mjs guards iface changes and counter resets.
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
            if (root.popupOpen)
                root._reloadStats()
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
            // The speed test is panel-gated: closing aborts mid-flight.
            root.cancelSpeedTest()
            return
        }
        // Fetch-on-open: no waiting for the next timer tick.
        // NOTE: the counters are NOT read here — they need root.iface from
        // gwProc's output. gwProc's onDone kicks the first FileView reload
        // once iface is known (fixes the empty-iface race that showed no data).
        if (isConnected) getIP()
        if (isConnected) gwProc.run()
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

    // ── Last-result persistence (H1) ─────────────────────────────────────
    // A completed run lands atomically (tmp+mv) in the state home so the
    // settings app can show "last test" and re-trigger via `network
    // speedtest` without a second fetcher. iface may be "" on headless
    // (IPC-initiated) runs — written honestly rather than probed for.
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

    // ── Interface throughput: raw sysfs counters for the active iface ────────
    // H8: two FileViews on the sysfs files (zero forks) replace the old `cat`
    // BoundedProcess. watchChanges stays false — the 2s popup-gated timer is
    // the delivery mechanism; sysfs inotify wouldn't fire anyway. Absorb runs
    // on the TX file's callback: the tick reloads RX then TX in order, so by
    // the time TX lands both texts belong to the same tick. The old
    // glued-counter incident class is structurally gone — no parser at all.
    readonly property string _rxPath:
        root.iface !== "" ? "/sys/class/net/" + root.iface + "/statistics/rx_bytes" : ""
    readonly property string _txPath:
        root.iface !== "" ? "/sys/class/net/" + root.iface + "/statistics/tx_bytes" : ""

    FileView {
        id: rxFile
        path: root._rxPath
        watchChanges: false
        printErrors: false
    }
    FileView {
        id: txFile
        path: root._txPath
        watchChanges: false
        printErrors: false
        onTextChanged: root._absorbStats()
    }

    function _absorbStats() {
        var rx = parseInt(rxFile.text(), 10)
        var tx = parseInt(txFile.text(), 10)
        if (isNaN(rx) || isNaN(tx) || root.iface === "") return
        var r = Model.throughputState(root._stats, root.iface, rx, tx, Date.now())
        root.rxRate = r.rxRate
        root.txRate = r.txRate
        root.rxTotal = r.rxTotal
        root.txTotal = r.txTotal
        root._stats = r.state
    }

    function _reloadStats() {
        if (root.iface === "") return
        rxFile.reload()      // ASYNC — absorb lands in txFile.onTextChanged
        txFile.reload()
    }

    // 2s while the popup is open — rates want a short window to feel live.
    Timer {
        id: statsTimer
        interval: 2000
        repeat: true
        running: root.hasNetwork && root.popupOpen
        onTriggered: if (root.isConnected) root._reloadStats()
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
