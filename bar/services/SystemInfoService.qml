/** Version: 1.0 - Themed system-info telemetry service **/
// =============================================================================
// SystemInfoService.qml — data backbone for the System Info dashboard
// =============================================================================
// Aggregates a hardware/OS profile + live metrics for the FastfetchOverlay
// (the "SYSTEM INFO" popup opened from the Arch logo). The overlay stays pure
// layout; all gathering/parsing lives here.
//
//   STATIC PROFILE   fastfetch --format json   (CPU/GPU/OS/kernel/packages/disks)
//   LIVE METRICS     /proc/meminfo + /proc/uptime + nvidia-smi  (polled while shown)
//   NETWORK / GEO    ip-api.com once per session (graceful "—" on failure)
//
// The overlay sets `active = true` while shown → liveTimer (2s) polls live
// metrics. Paused when closed (CPU + OLED burn-in). Every metric degrades to
// "—"/0 when its source is absent, so no card ever breaks the layout.
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false

    // =========================================================================
    // STATIC PROFILE  (fastfetch --format json — refreshed on each open)
    // =========================================================================
    property string userName: ""
    property string hostName: ""
    property string cpuModel: "—"
    property int cpuThreads: 0
    property real cpuMaxGhz: 0.0            // 5.575 → "5.58 GHz"
    property string gpuName: "—"
    property string gpuDriver: ""
    property string gpuType: ""             // "Discrete" / "Integrated"
    property string gpuVendor: ""
    property real memTotalGiB: 0.0
    property string osName: ""
    property string osCodename: ""          // "yarara"
    property string osVersion: ""           // "26.05"
    property string kernelName: ""          // "Linux"
    property string kernelRelease: ""       // "7.1.3"
    property string arch: ""                // "x86_64"
    property int pkgAll: 0
    property int pkgSystem: 0
    property int pkgUser: 0
    property string shellName: ""           // "zsh" / "bash" (from $SHELL)
    property var disks: []                  // [{dev,mount,usedLabel,totalLabel,pct}]
    property int osAgeDays: 0
    property string installDate: ""         // "2026-07-04"

    // =========================================================================
    // LIVE METRICS  (refreshed every 2s while active)
    // =========================================================================
    property real memUsedGiB: 0.0
    property real memPct: 0.0               // 0..100 — drives the radial
    property real uptimeSeconds: 0.0
    property string uptimeStr: "0s"
    property int gpuTempC: 0                // 0 = unknown
    property real gpuPowerW: 0.0
    property int gpuUsagePct: 0

    // =========================================================================
    // NETWORK / GEO
    // =========================================================================
    property string geoCity: ""
    property string geoCountry: ""
    property bool geoDone: false            // gate: curl at most once per session

    property bool active: false             // overlay drives this with shown-state
    property bool loading: false

    // =========================================================================
    // CONTROL
    // =========================================================================
    function refresh() {
        root.loading = true
        if (!ffProc.running) ffProc.running = true
        if (!shellProc.running) shellProc.running = true
        root.pollLive()
        if (!root.geoDone && !geoProc.running) geoProc.running = true
    }

    function pollLive() {
        if (!liveProc.running) liveProc.running = true
        if (!nvidiaProc.running) nvidiaProc.running = true
    }

    // =========================================================================
    // FORMAT HELPERS  (overlay reads these too)
    // =========================================================================
    function fmtUptime(sec) {
        var s = Math.max(0, Math.floor(sec || 0))
        if (s < 60) return s + "s"
        var m = Math.floor(s / 60)
        if (m < 60) return m + "m " + (s % 60) + "s"
        var h = Math.floor(m / 60)
        if (h < 24) return h + "h " + (m % 60) + "m"
        var d = Math.floor(h / 24)
        return d + "d " + (h % 24) + "h"
    }

    function _giB(bytes) {
        return (Math.round((bytes || 0) / 1073741824 * 100) / 100).toFixed(2) + " GiB"
    }
    function _best(bytes) {
        var b = bytes || 0
        if (b >= 1099511627776) return (Math.round(b / 1099511627776 * 100) / 100).toFixed(2) + " TiB"
        return (Math.round(b / 1073741824 * 100) / 100).toFixed(2) + " GiB"
    }

    // =========================================================================
    // fastfetch JSON profile
    // =========================================================================
    function _findBlock(arr, type) {
        for (var i = 0; i < arr.length; i++) {
            if (arr[i].type === type) return arr[i].result
        }
        return null
    }

    Process {
        id: ffProc
        property string buffer: ""
        command: ["fastfetch", "--format", "json", "--logo", "none"]
        stdout: SplitParser { onRead: function(data) { ffProc.buffer += data } }
        onRunningChanged: if (!running) {
            var raw = ffProc.buffer.trim()
            ffProc.buffer = ""
            if (raw) {
                try {
                    var data = JSON.parse(raw)

                    var title = root._findBlock(data, "Title")
                    if (title) {
                        root.userName = title.userName || ""
                        root.hostName = title.hostName || ""
                    }
                    var cpu = root._findBlock(data, "CPU")
                    if (cpu) {
                        root.cpuModel = cpu.cpu || "—"
                        root.cpuThreads = (cpu.cores && cpu.cores.logical) ? cpu.cores.logical : 0
                        root.cpuMaxGhz = (cpu.frequency && cpu.frequency.max) ? cpu.frequency.max / 1000 : 0
                    }
                    var gpu = root._findBlock(data, "GPU")
                    if (gpu && gpu.length > 0) {
                        root.gpuName = gpu[0].name || "—"
                        root.gpuDriver = gpu[0].driver || ""
                        root.gpuType = gpu[0].type || ""
                        root.gpuVendor = gpu[0].vendor || ""
                    }
                    var mem = root._findBlock(data, "Memory")
                    if (mem && mem.total) root.memTotalGiB = Math.round(mem.total / 1073741824 * 100) / 100

                    var os = root._findBlock(data, "OS")
                    if (os) {
                        root.osName = os.name || ""
                        root.osCodename = os.codename || ""
                        root.osVersion = os.versionID || ""
                    }
                    var ker = root._findBlock(data, "Kernel")
                    if (ker) {
                        root.kernelName = ker.name || ""
                        root.kernelRelease = ker.release || ""
                        root.arch = ker.architecture || ""
                    }
                    var pkgs = root._findBlock(data, "Packages")
                    if (pkgs) {
                        root.pkgAll = pkgs.all || 0
                        root.pkgSystem = pkgs.nixSystem || 0
                        root.pkgUser = pkgs.nixUser || 0
                    }

                    var diskArr = root._findBlock(data, "Disk")
                    if (diskArr && diskArr.length !== undefined) {
                        var out = []
                        var rootCreated = ""
                        for (var i = 0; i < diskArr.length; i++) {
                            var d = diskArr[i]
                            // skip subvolumes / read-only (e.g. /nix/store dup of /)
                            var isRegular = true
                            if (d.volumeType && d.volumeType.length > 0) {
                                isRegular = false
                                for (var v = 0; v < d.volumeType.length; v++) {
                                    if (d.volumeType[v] === "Regular") { isRegular = true; break }
                                }
                            }
                            if (!isRegular) continue
                            if (!d.bytes || !d.bytes.total) continue
                            if (out.length >= 5) break   // bound the list so the card can't overflow
                            var pct = Math.round(d.bytes.used / d.bytes.total * 100)
                            var createdDate = d.createTime ? d.createTime.substring(0, 10) : ""
                            out.push({
                                dev: d.mountFrom || d.mountpoint || "—",
                                mount: d.mountpoint || "",
                                usedLabel: root._giB(d.bytes.used),
                                totalLabel: root._best(d.bytes.total),
                                pct: pct
                            })
                            if (d.mountpoint === "/" && createdDate) rootCreated = createdDate
                        }
                        root.disks = out
                        if (rootCreated) {
                            root.installDate = rootCreated
                            var p = rootCreated.split("-")
                            if (p.length === 3) {
                                var createdMs = Date.UTC(+p[0], +p[1] - 1, +p[2])
                                root.osAgeDays = Math.max(0, Math.floor((Date.now() - createdMs) / 86400000))
                            }
                        }
                    }
                } catch (e) {
                    console.log("[SystemInfoService] fastfetch parse error:", e)
                }
            }
            root.loading = false
        }
    }

    // login shell — fastfetch mis-reports it (sees the launching wrapper), so
    // read $SHELL directly and basename it in QML.
    Process {
        id: shellProc
        command: ["sh", "-c", "echo $SHELL"]
        stdout: SplitParser {
            onRead: function(data) {
                var s = data.trim()
                if (s) {
                    var slash = s.lastIndexOf("/")
                    root.shellName = slash >= 0 ? s.substring(slash + 1) : s
                }
            }
        }
    }

    // =========================================================================
    // LIVE METRICS — /proc/meminfo + /proc/uptime in one read
    // =========================================================================
    Process {
        id: liveProc
        property string buffer: ""
        command: ["sh", "-c", "cat /proc/meminfo /proc/uptime"]
        stdout: SplitParser { onRead: function(data) { liveProc.buffer += data + "\n" } }
        onRunningChanged: if (!running) {
            var lines = liveProc.buffer.split("\n")
            liveProc.buffer = ""
            var memTotal = 0, memAvail = 0, up = 0
            for (var i = 0; i < lines.length; i++) {
                var ln = lines[i]
                var mt = ln.match(/^MemTotal:\s+(\d+)/)
                if (mt) { memTotal = parseInt(mt[1], 10); continue }
                var ma = ln.match(/^MemAvailable:\s+(\d+)/)
                if (ma) { memAvail = parseInt(ma[1], 10); continue }
                var uu = ln.match(/^(\d+\.\d+)\s+\d+\.\d+/)
                if (uu) up = parseFloat(uu[1])
            }
            // values from /proc/meminfo are kB
            if (memTotal > 0) {
                var usedKb = Math.max(0, memTotal - memAvail)
                root.memTotalGiB = Math.round(memTotal / 1048576 * 100) / 100
                root.memUsedGiB = Math.round(usedKb / 1048576 * 100) / 100
                root.memPct = Math.min(100, Math.round(usedKb / memTotal * 1000) / 10)
            }
            if (up > 0) {
                root.uptimeSeconds = up
                root.uptimeStr = root.fmtUptime(up)
            }
        }
    }

    // GPU temp / power / usage (NVIDIA). No GPU or no driver → stays 0 → "—".
    Process {
        id: nvidiaProc
        command: ["nvidia-smi", "--query-gpu=temperature.gpu,power.draw,utilization.gpu", "--format=csv,noheader,nounits"]
        stdout: SplitParser {
            onRead: function(data) {
                var s = (data || "").trim()
                if (!s) return
                var parts = s.split(", ")
                if (parts.length < 3) return
                var t = parseInt(parts[0], 10)
                var p = parseFloat(parts[1])
                var u = parseInt(parts[2], 10)
                if (!isNaN(t)) root.gpuTempC = t
                if (!isNaN(p)) root.gpuPowerW = Math.round(p * 100) / 100
                if (!isNaN(u)) root.gpuUsagePct = u
            }
        }
    }

    // =========================================================================
    // GEO — curl ip-api.com once per session; "—" on any failure
    // =========================================================================
    Process {
        id: geoProc
        property string buffer: ""
        command: ["sh", "-c", "curl -s --max-time 6 'http://ip-api.com/json/?fields=city,country,countryCode' || true"]
        stdout: SplitParser { onRead: function(data) { geoProc.buffer += data } }
        onRunningChanged: if (!running) {
            var raw = geoProc.buffer.trim()
            geoProc.buffer = ""
            root.geoDone = true
            try {
                var j = JSON.parse(raw)
                if (j && !j.error && j.city) {
                    root.geoCity = j.city
                    root.geoCountry = j.country || ""
                }
            } catch (e) {
                // offline / rate-limited / blocked — keep "—"
            }
        }
    }

    // =========================================================================
    // LIVE POLL TIMER (runs only while the overlay is shown)
    // =========================================================================
    Timer {
        id: liveTimer
        interval: 2000
        repeat: true
        running: root.active
        onTriggered: root.pollLive()
    }
}
