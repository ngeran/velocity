/** Version: 21.1 - Fixed reset timing **/
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

    // One-shot presence probe; gates the poll timer on exit.
    Process {
        id: detectProc
        command: ["sh", "-c", "command -v nmcli >/dev/null && nmcli general >/dev/null 2>&1"]
        onExited: function(code) {
            root.hasNetwork = (code === 0)
            netPollTimer.running = root.hasNetwork
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
        }
    }

    function _reset() {
        root.connectionType = ""
        root.isConnected = false
        root.ssid = ""
        root.ipAddress = ""
        root.signalStrength = 0
        if (Config.DebugConfig.debugEnabled) console.log("[NetworkService] Reset")
    }

    Component.onCompleted: detectProc.running = true
}
