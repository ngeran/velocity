// =============================================================================
// SysInfoService.qml — System Information Service
// =============================================================================
//
// Gathers real host info (OS, kernel, hostname, uptime, user) using the same
// Process + SplitParser + Timer pattern as NetworkService. Static values (OS,
// kernel, hostname, user) are read once on load; uptime refreshes every 30s.
//
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io

Item {
    id: root

    property string osName: "Linux"
    property string osPrettyName: "Linux"
    property string hostname: "unknown"
    property string kernel: "unknown"
    property string uptime: "—"
    property string userName: "user"

    Component.onCompleted: {
        root.refreshStatic()
        root.refreshUptime()
        console.log("[SysInfo] Service loaded")
    }

    // ── Refresh static values (OS, kernel, hostname, user) ───────────────────
    function refreshStatic() {
        osProc.running = true
        kernelProc.running = true
        hostnameProc.running = true
        userProc.running = true
    }

    function refreshUptime() {
        uptimeProc.running = true
    }

    // ── OS pretty name: PRETTY_NAME="Arch Linux" ─────────────────────────────
    Process {
        id: osProc
        command: ["sh", "-c", ". /etc/os-release 2>/dev/null && echo \"$PRETTY_NAME|$NAME\""]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { osProc.buffer += data } }
        onRunningChanged: {
            if (!running && osProc.buffer.length > 0) {
                var parts = osProc.buffer.trim().split("|")
                root.osPrettyName = parts[0] || root.osPrettyName
                root.osName = parts[1] || root.osName
                osProc.buffer = ""
            }
        }
    }

    // ── Kernel: uname -r ─────────────────────────────────────────────────────
    Process {
        id: kernelProc
        command: ["uname", "-r"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { kernelProc.buffer += data } }
        onRunningChanged: {
            if (!running && kernelProc.buffer.length > 0) {
                root.kernel = kernelProc.buffer.trim()
                kernelProc.buffer = ""
            }
        }
    }

    // ── Hostname ─────────────────────────────────────────────────────────────
    Process {
        id: hostnameProc
        command: ["sh", "-c", "hostnamectl hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || hostname 2>/dev/null"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { hostnameProc.buffer += data } }
        onRunningChanged: {
            if (!running && hostnameProc.buffer.length > 0) {
                root.hostname = hostnameProc.buffer.trim()
                hostnameProc.buffer = ""
            }
        }
    }

    // ── Username: whoami ─────────────────────────────────────────────────────
    Process {
        id: userProc
        command: ["sh", "-c", "whoami"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { userProc.buffer += data } }
        onRunningChanged: {
            if (!running && userProc.buffer.length > 0) {
                var u = userProc.buffer.trim()
                if (u.length > 0)
                    root.userName = u.charAt(0).toUpperCase() + u.slice(1)
                userProc.buffer = ""
            }
        }
    }

    // ── Uptime: "up 2 hours, 15 minutes" ────────────────────────────────────
    Process {
        id: uptimeProc
        command: ["sh", "-c", "uptime -p 2>/dev/null | sed 's/^up //' || cat /proc/uptime"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { uptimeProc.buffer += data } }
        onRunningChanged: {
            if (!running && uptimeProc.buffer.length > 0) {
                var raw = uptimeProc.buffer.trim()
                if (raw.length > 0 && raw.indexOf("up") === 0) {
                    root.uptime = raw
                } else {
                    // Fallback: /proc/uptime seconds → human readable
                    var secs = parseFloat(raw.split(" ")[0])
                    if (!isNaN(secs) && secs > 0)
                        root.uptime = root._formatUptime(secs)
                }
                uptimeProc.buffer = ""
            }
        }
    }

    function _formatUptime(totalSecs) {
        var d = Math.floor(totalSecs / 86400)
        var h = Math.floor((totalSecs % 86400) / 3600)
        var m = Math.floor((totalSecs % 3600) / 60)
        var parts = []
        if (d > 0) parts.push(d + (d === 1 ? " day" : " days"))
        if (h > 0) parts.push(h + " hour" + (h === 1 ? "" : "s"))
        if (m > 0) parts.push(m + " min")
        return parts.length > 0 ? parts.join(", ") : "less than a minute"
    }

    // ── Periodic uptime refresh ──────────────────────────────────────────────
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: root.refreshUptime()
    }
}
