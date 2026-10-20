// =============================================================================
// SysInfoService.qml — System Information Service
// =============================================================================
//
// Host identity the dashboard shows: hostname, user, uptime. Static values
// (hostname, user) are read once on load; uptime refreshes every 30s while
// the dashboard is open (and on CoreSystemPane open).
//
// C2 trim: the live cpu/mem/gpu/disk metrics and the DMI board fields had
// ZERO consumers (CoreEngineService owns live metrics; the bar's
// SystemInfoService owns board identity for FastfetchOverlay) — removed with
// per-property proofs. osName/osPrettyName/kernel were equally unread.
//
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io
import "../config" as Config

Item {
    id: root

    property string hostname: "unknown"
    property string uptime: "—"
    property string userName: "user"

    Component.onCompleted: {
        root.refreshStatic()
        root.refreshUptime()
        console.log("[SysInfo] Service loaded")
    }

    // ── Refresh static values ────────────────────────────────────────────────
    function refreshStatic() {
        hostnameProc.running = true
        userProc.running = true
    }

    function refreshUptime() {
        uptimeProc.running = true
    }

    // ── Hostname ─────────────────────────────────────────────────────────────
    Process {   // unbounded-ok: one-shot local read (sysfs/proc) — no hang or flood risk
        id: hostnameProc
        command: ["sh", "-c", "hostnamectl hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || hostname 2>/dev/null"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { hostnameProc.buffer += data + "\n" } }
        onRunningChanged: {
            if (!running && hostnameProc.buffer.length > 0) {
                root.hostname = hostnameProc.buffer.trim()
                hostnameProc.buffer = ""
            }
        }
    }

    // ── Username: whoami ─────────────────────────────────────────────────────
    Process {   // unbounded-ok: one-shot local command — timeout migration queued
        id: userProc
        command: ["sh", "-c", "whoami"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { userProc.buffer += data + "\n" } }
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
    Process {   // unbounded-ok: one-shot local read (sysfs/proc) — no hang or flood risk
        id: uptimeProc
        command: ["sh", "-c", "uptime -p 2>/dev/null | sed 's/^up //' || cat /proc/uptime"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { uptimeProc.buffer += data + "\n" } }
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
        running: Config.SharedState.dashboardVisible  // only when the dashboard is open
        repeat: true
        triggeredOnStart: false
        onTriggered: root.refreshUptime()
    }
}
