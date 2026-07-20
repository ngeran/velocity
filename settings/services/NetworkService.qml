// =============================================================================
// NetworkService.qml — Network State & Traffic Monitoring
// =============================================================================
//
// Live network state for the settings dashboard. All probes use commands
// verified against the installed NetworkManager/iproute2 field sets.
//
// PUBLIC API (unchanged)
//   property string connectionType — "wifi" | "ethernet" | "" (disconnected)
//   property bool   isConnected    — true when any link is connected
//   property string interfaceName  — e.g. "wlan0"
//   property real   signalStrength — 0.0–1.0 (wifi from nmcli; 1.0 on ethernet)
//   property string ssid           — active WiFi SSID ("" otherwise)
//   property string ipAddress      — IPv4 of the default route
//   property real   rxBytes        — cumulative RX bytes (/proc/net/dev)
//   property real   txBytes        — cumulative TX bytes (/proc/net/dev)
//
// IMPLEMENTATION
//   linkProbe   (3s)  nmcli device status   → type / iface / connected
//   wifiProbe   (4s)  nmcli dev wifi        → SSID + SIGNAL (active AP)
//   ipProbe     (3s)  ip -4 route get 1     → IPv4 + iface fallback
//   procNetDev  (1.5s) cat /proc/net/dev    → RX/TX byte counters
//
// NOTE: `nmcli -f SIGNAL,SSID,IP4 device` is INVALID (those fields don't exist
// on the device-status view) — it errors out and yields nothing. The probes
// below use the correct views (device status vs. dev wifi) per field.
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io
import "../config" as Config

Item {
    id: root
    visible: false

    // =========================================================================
    // PUBLIC PROPERTIES
    // =========================================================================

    property string connectionType: ""
    property bool isConnected: false
    property string interfaceName: ""
    property real signalStrength: 0.0
    property string ssid: ""
    property string ipAddress: ""
    property real rxBytes: 0
    property real txBytes: 0

    // =========================================================================
    // LINK PROBE — connection type / interface / connected flag
    //   nmcli -t -f TYPE,STATE,DEVICE,CONNECTION device
    //   → "wifi:connected:wlan0:Vectornet-5" / "ethernet:connected:enp2s0:..."
    // =========================================================================

    Process {
        id: linkProbe
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE,DEVICE,CONNECTION device | grep -E '^(wifi|ethernet):connected' | head -1"]
        property string buffer: ""

        stdout: SplitParser {
            onRead: function(data) { linkProbe.buffer += data }
        }

        onRunningChanged: {
            if (!running) {
                var line = linkProbe.buffer.trim()
                if (line.length > 0) {
                    var parts = line.split(":")
                    // TYPE:STATE:DEVICE:CONNECTION — CONNECTION (profile name) may contain ':'
                    root.connectionType = parts[0] || ""
                    root.isConnected = (parts[1] === "connected")
                    root.interfaceName = parts[2] || ""
                    // Ethernet has no wireless signal → treat as full strength.
                    if (root.connectionType === "ethernet") root.signalStrength = 1.0
                } else {
                    root._resetLink()
                }
                linkProbe.buffer = ""
            }
        }
    }

    Timer {
        interval: 3000
        running: Config.SharedState.dashboardVisible  // only when the dashboard is open
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!linkProbe.running) linkProbe.running = true }
    }

    // =========================================================================
    // WIFI PROBE — real SSID + signal of the active access point
    //   nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi | grep '^yes:'
    //   → "yes:Vectornet-5:45"
    // =========================================================================

    Process {
        id: wifiProbe
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi | grep '^yes:' | head -1"]
        property string buffer: ""

        stdout: SplitParser {
            onRead: function(data) { wifiProbe.buffer += data }
        }

        onRunningChanged: {
            if (!running) {
                var line = wifiProbe.buffer.trim()
                if (line.length > 0) {
                    // ACTIVE:SSID:SIGNAL — SSID may itself contain ':' so slice ends.
                    var parts = line.split(":")
                    var sig = parseInt(parts[parts.length - 1]) || 0
                    root.ssid = parts.slice(1, parts.length - 1).join(":")
                    root.signalStrength = Math.max(0, Math.min(1, sig / 100))
                } else {
                    // No active wifi → clear wifi-only state (ethernet untouched).
                    if (root.connectionType !== "ethernet") {
                        root.ssid = ""
                        root.signalStrength = 0.0
                    }
                }
                wifiProbe.buffer = ""
            }
        }
    }

    Timer {
        interval: 4000
        running: Config.SharedState.dashboardVisible  // only when the dashboard is open
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!wifiProbe.running) wifiProbe.running = true }
    }

    // =========================================================================
    // IP PROBE — IPv4 of the default route (+ interface fallback)
    //   ip -4 route get 1 → "... dev wlan0 src 10.0.0.59 ..."
    // =========================================================================

    Process {
        id: ipProbe
        command: ["sh", "-c", "ip -4 route get 1 2>/dev/null"]
        property string buffer: ""

        stdout: SplitParser {
            onRead: function(data) { ipProbe.buffer += data }
        }

        onRunningChanged: {
            if (!running) {
                var s = ipProbe.buffer.trim()
                var srcMatch = s.match(/src\s+([\d.]+)/)
                var devMatch = s.match(/dev\s+(\S+)/)
                root.ipAddress = srcMatch ? srcMatch[1] : ""
                if (devMatch && root.interfaceName === "") root.interfaceName = devMatch[1]
                ipProbe.buffer = ""
            }
        }
    }

    Timer {
        interval: 3000
        running: Config.SharedState.dashboardVisible  // only when the dashboard is open
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!ipProbe.running) ipProbe.running = true }
    }

    // =========================================================================
    // TRAFFIC PROBE — cumulative RX/TX byte counters from /proc/net/dev
    // =========================================================================

    Process {
        id: procNetDev
        command: ["sh", "-c", "cat /proc/net/dev"]

        // SplitParser invokes onRead once per line (newlines already stripped),
        // so we parse each line as it arrives rather than accumulating a buffer.
        stdout: SplitParser {
            onRead: function(line) {
                var parts = line.trim().split(/\s+/)
                if (parts.length >= 10) {
                    var iface = parts[0].replace(/:/, "")
                    if (iface === root.interfaceName) {
                        // Column 1 = RX bytes, column 9 = TX bytes
                        root.rxBytes = parseFloat(parts[1]) || 0
                        root.txBytes = parseFloat(parts[9]) || 0
                    }
                }
            }
        }
    }

    Timer {
        interval: 1500
        running: Config.SharedState.dashboardVisible  // only when the dashboard is open
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!procNetDev.running) procNetDev.running = true }
    }

    // =========================================================================
    // PRIVATE HELPERS
    // =========================================================================

    function _resetLink() {
        root.connectionType = ""
        root.isConnected = false
        root.interfaceName = ""
        root.signalStrength = 0.0
        root.ssid = ""
        root.ipAddress = ""
        // rxBytes/txBytes retained so speed deltas stay computable across blips.
    }
}
