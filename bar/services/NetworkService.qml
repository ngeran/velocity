/** Version: 23 - primary DNS only + Wi-Fi radio on/off toggle **/
pragma Singleton
import QtQuick
import Quickshell.Io
import "../config" as Config

Item {
    id: root
    visible: false

    property string connectionType: ""
    property bool isConnected: false
    property string ssid: ""
    property string ipAddress: ""

    // Active Wi-Fi signal strength (0–100). Only meaningful for
    // connectionType === "wifi"; reset to 0 for ethernet / disconnected.
    property int signalStrength: 0

    // nmcli presence — when absent we stop polling instead of forking a failing
    // process forever and showing a misleading "DISCONNECTED" state.
    property bool hasNetwork: true

    // ── Link diagnostics for the WiFi popup ──────────────────────────────
    property string gateway: ""     // default IPv4 gateway, e.g. "10.0.0.1"
    property string iface: ""       // active interface, e.g. "wlp10s0"
    property string dns: ""         // PRIMARY DNS server only, e.g. "75.75.75.75"
    property real latencyMs: -1     // ping RTT (avg) to a target; -1 = no reply
    property bool wifiRadio: true   // Wi-Fi radio on/off (nmcli radio wifi)

    // One-shot presence probe; gates the poll timer on exit.
    Process {
        id: detectProc
        command: ["sh", "-c", "command -v nmcli >/dev/null && nmcli general >/dev/null 2>&1"]
        onExited: function(code) {
            root.hasNetwork = (code === 0)
            netPollTimer.running = root.hasNetwork
            diagTimer.running = root.hasNetwork
        }
    }

    // Simple command that just outputs everything
    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f TYPE,NAME connection show --active 2>/dev/null | grep '^802-11-wireless\\|^802-3-ethernet' | head -1"]
        stdout: SplitParser {
            onRead: function(data) {
                if (Config.DebugConfig.debugEnabled) console.log("[NetworkService] OUTPUT:", data)
                // Parse the output directly here
                var trimmed = data.trim()
                if (trimmed !== "") {
                    if (trimmed.startsWith("802-11-wireless:")) {
                        root.connectionType = "wifi"
                        root.ssid = trimmed.substring("802-11-wireless:".length)
                        root.isConnected = true
                        if (Config.DebugConfig.debugEnabled) console.log("[NetworkService] Found WiFi SSID:", root.ssid)
                    } else if (trimmed.startsWith("802-3-ethernet:")) {
                        root.connectionType = "ethernet"
                        root.ssid = trimmed.substring("802-3-ethernet:".length)
                        root.isConnected = true
                        root.signalStrength = 0   // ethernet has no RF signal
                        if (Config.DebugConfig.debugEnabled) console.log("[NetworkService] Found Ethernet:", root.ssid)
                    }
                } else {
                    // No connection found
                    root._reset()
                }
            }
        }
        stderr: SplitParser {
            onRead: function(data) {
                console.warn("[NetworkService] ERROR:", data)
            }
        }
        onRunningChanged: {
            if (!running) {
                if (Config.DebugConfig.debugEnabled) console.log("[NetworkService] Process finished")
                // If we didn't find a connection, reset
                if (!root.isConnected) {
                    root._reset()
                }
                // Now get IP if connected
                if (root.isConnected) {
                    getIP()
                }
            }
        }
    }

    // Separate process for IP
    Process {
        id: ipProc
        command: ["sh", "-c", "ip -4 route get 1 2>/dev/null | grep -oE 'src [0-9.]+' | awk '{print $2}'"]
        stdout: SplitParser {
            onRead: function(data) {
                var ip = data.trim()
                if (ip !== "") {
                    root.ipAddress = ip
                    if (Config.DebugConfig.debugEnabled) console.log("[NetworkService] Found IP:", ip)
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                if (Config.DebugConfig.debugEnabled) console.log("[NetworkService] IP process finished")
            }
        }
    }

    function getIP() {
        if (!ipProc.running) {
            ipProc.running = true
        }
    }

    // Active Wi-Fi signal strength (0–100). Uses the cached scan (--rescan no)
    // so it never triggers a fresh scan mid-poll. Emits nothing when not on
    // Wi-Fi, leaving signalStrength at whatever the last connection state set.
    Process {
        id: signalProc
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SIGNAL device wifi list --rescan no 2>/dev/null | grep '^yes:' | head -1 | cut -d: -f2"]
        stdout: SplitParser {
            onRead: function(data) {
                var s = data.trim()
                if (s !== "") {
                    var n = parseInt(s, 10)
                    if (!isNaN(n)) root.signalStrength = n
                }
            }
        }
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

    // ── PRIMARY DNS only: nmcli terse emits `IP4.DNS[1]:<ip>` (':' separator) ─
    Process {
        id: dnsProc
        command: ["sh", "-c", "nmcli -t -f IP4.DNS dev show 2>/dev/null | grep ':' | head -1"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { dnsProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                var line = dnsProc.buffer.trim()
                dnsProc.buffer = ""
                if (line.indexOf(":") !== -1) {
                    root.dns = line.substring(line.indexOf(":") + 1).trim()
                } else {
                    root.dns = ""
                }
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
                // rtt min/avg/max/mdev = a/b/c/d ms  → avg = group 2
                var m = out.match(/rtt[^=]*=\s*([0-9.]+)\/([0-9.]+)/)
                root.latencyMs = m ? parseFloat(m[2]) : -1
            }
        }
    }

    // ── Wi-Fi radio state (on/off) for the popup toggle ─────────────────────
    Process {
        id: radioProc
        command: ["sh", "-c", "nmcli -t -f WIFI radio wifi 2>/dev/null"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { radioProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                root.wifiRadio = radioProc.buffer.trim().indexOf("enabled") !== -1
                radioProc.buffer = ""
            }
        }
    }

    // Runs the toggle command. (Quickshell.exec() does NOT exist in this build.)
    Process { id: radioToggleProc }

    // Re-probe the radio shortly after a toggle (before the next 5s poll).
    Timer { id: radioRefresh; interval: 1500; onTriggered: if (!radioProc.running) radioProc.running = true }

    // Toggle the Wi-Fi radio. Optimistic flip + a fresh probe to confirm.
    function toggleRadio() {
        radioToggleProc.command = ["nmcli", "radio", "wifi", root.wifiRadio ? "off" : "on"]
        radioToggleProc.running = true
        root.wifiRadio = !root.wifiRadio
        radioRefresh.restart()
    }

    Timer {
        id: netPollTimer
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (Config.DebugConfig.debugEnabled) console.log("[NetworkService] Polling...")
            // Only reset if we're not already connected (prevents flash)
            if (!root.isConnected) {
                // Keep current state until we get new data
            }
            if (!netProc.running) netProc.running = true
            if (!signalProc.running) signalProc.running = true
            if (!radioProc.running) radioProc.running = true
        }
    }

    // Gateway / DNS / latency refresh — slower cadence (these change rarely
    // and ping is a network round-trip). Only fires while connected.
    Timer {
        id: diagTimer
        interval: 10000
        repeat: true
        triggeredOnStart: true
        running: root.hasNetwork
        onTriggered: {
            if (!root.isConnected) return
            if (!gwProc.running) gwProc.running = true
            if (!dnsProc.running) dnsProc.running = true
            if (!pingProc.running) pingProc.running = true
        }
    }

    function _reset() {
        root.connectionType = ""
        root.isConnected = false
        root.ssid = ""
        root.ipAddress = ""
        root.signalStrength = 0
        root.gateway = ""
        root.iface = ""
        root.dns = ""
        root.latencyMs = -1
        if (Config.DebugConfig.debugEnabled) console.log("[NetworkService] Reset")
    }

    Component.onCompleted: detectProc.running = true
}
