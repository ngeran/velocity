// =============================================================================
// CoreEngineService.qml — telemetry aggregator + deepcool-py feed publisher
// =============================================================================
//
// Single producer of the "Core Engine" dashboard data AND the live values pushed
// to the deepcool-py USB sink. Every ~1s it:
//   1. refreshes its own readers (CPU agg+per-core, CPU GHz, RAM, swap, disk),
//   2. aggregates those + GpuService + ThermalService into one object,
//   3. writes ~/.cache/deepcool/metrics.json (deepcool-py watches this file).
//
// Dashboard views bind to these properties (live); deepcool-py reads the file.
// SysInfoService is left untouched — this service is self-sufficient for the LCD
// feed to avoid coupling cadence (bar polls 5s; the LCD wants ~1s).
//
// READER ENGINE (ported from omarchy-system-monitor's Metrics.qml): /proc and
// /sys are read with FileView.reload() on the timer — ZERO forked processes
// per tick (the old engine forked sh+free every second and sh again for GHz).
// watchChanges stays false because inotify doesn't fire on procfs anyway.
// History ring buffers (cpuHistory/memoryHistory, 2-min window via History.js)
// live HERE, singleton-owned, so charts survive the dashboard Loader being
// torn down on panel close.
//
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
import Quickshell.Io
import "History.js" as History

Item {
    id: root

    // ── exposed for dashboard binding ───────────────────────────────────────
    property real cpuUsage: 0        // %  (aggregate)
    property var perCoreLoad: []     // [% , ...] one per logical core
    property real cpuGhz: 0
    property real ramUsedGB: 0
    property real ramTotalGB: 0
    property real ramPct: 0
    property real swapUsedGB: 0
    property real swapTotalGB: 0
    property real swapPct: 0
    property real diskUsedTB: 0
    property real diskTotalTB: 0
    property real diskPct: 0
    property var disks: []          // [{device,fstype,mount,usedGB,totalGB,pct}] all real data filesystems

    // ── 2-min rolling history for the Core charts ({time,value}, oldest first)
    property var cpuHistory: []
    property var memoryHistory: []
    readonly property int historyWindowMs: 120000
    readonly property int historyMaxSamples: 130

    // ── internal CPU delta state ────────────────────────────────────────────
    property real _cpuPrevBusy: 0
    property real _cpuPrevTotal: 0
    property var _perCorePrev: ({})

    // ── metrics.json path (~/.cache/deepcool/metrics.json) ──────────────────
    // GenericCacheLocation is the SHARED ~/.cache (CacheLocation is app-specific
    // → ~/.cache/quickshell here). deepcool-py reads this exact path.
    property string metricsPath: StandardPaths.writableLocation(StandardPaths.GenericCacheLocation)
                                       .toString().replace("file://", "") + "/deepcool/metrics.json"

    // ── Consumer gating (Shibumi refcount, two bools) ──────────────────────
    // The 1s engine exists for exactly two consumers: the deepcool LCD (an
    // external daemon reading metrics.json — probed every 60s; it is NOT
    // running on this box today) and the dashboard's Core tab (Loader-
    // instantiated; sets coreVisible from its Completed/Destruction). With
    // neither present the engine ticks ZERO times — previously it forked a
    // printf every second and dragged Gpu/Thermal polls along, feeding a
    // file nothing read (~130 forks/min while the panel was hidden).
    property bool coreVisible: false                     // Core tab session
    property bool lcdPresent: false                      // deepcool reader probe
    readonly property bool telemetryWanted: coreVisible || lcdPresent

    Process {
        id: lcdProbe
        // [d]eepcool regex self-match guard: pgrep -f scans full command
        // lines, and anything probing THIS file's path (~/.cache/deepcool/…)
        // would otherwise read as the LCD daemon and light the feed up.
        command: ["sh", "-c", "pgrep -f '[d]eepcool' >/dev/null 2>&1"]
        onExited: function(code) { root.lcdPresent = (code === 0) }
    }
    Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!lcdProbe.running) lcdProbe.running = true
    }

    // metrics.json via FileView's WRITE path (setText) — same truncate+write
    // semantics as the old `printf >`, minus the per-second sh fork.
    FileView {
        id: metricsFile
        path: root.metricsPath
        printErrors: false
    }

    // One-shot: ensures the deepcool cache dir exists at startup so publish()
    // doesn't need a per-tick `mkdir -p` fork (mkdir is a separate binary).
    property Process initProc: Process { command: []; running: false }

    Component.onCompleted: {
        console.log("[CoreEngine] publishing →", root.metricsPath)
        var dir = root.metricsPath.substring(0, root.metricsPath.lastIndexOf("/"))
        root.initProc.command = ["sh", "-c", "mkdir -p '" + dir + "'"]
        root.initProc.running = true
    }

    // ── CPU aggregate + per-core from /proc/stat (FileView, no fork) ────────
    // FRESHNESS CONTRACT: reload() is ASYNC — a synchronous text() right after
    // returns the stale cache, and onLoaded does not re-fire per reload (both
    // proven live; the old onLoaded pattern froze values at the first tick).
    // Parsing instead on textChanged — which fires whenever a completed read
    // actually changed the cache — makes every reload land.
    FileView {
        id: statFile
        path: "/proc/stat"
        watchChanges: false
        onTextChanged: root.parseStat(text())
    }

    function parseStat(raw) {
        var lines = String(raw).trim().split("\n")
        var perCore = []
        var prev = root._perCorePrev
        for (var i = 0; i < lines.length; i++) {
            var f = lines[i].trim().split(/\s+/)
            if (f.length < 5 || f[0].substring(0, 3) !== "cpu") continue
            var label = f[0]
            var user = +f[1], nice = +f[2], sys = +f[3], idle = +f[4]
            var iowait = f.length > 5 ? +f[5] : 0
            var irq    = f.length > 6 ? +f[6] : 0
            var softirq= f.length > 7 ? +f[7] : 0
            var steal  = f.length > 8 ? +f[8] : 0
            var busy = user + nice + sys + irq + softirq
            var total = busy + idle + iowait + steal
            if (label === "cpu") {
                var db = busy - root._cpuPrevBusy
                var dt = total - root._cpuPrevTotal
                if (dt > 0 && root._cpuPrevTotal > 0)
                    root.cpuUsage = Math.max(0, Math.min(100, Math.round(db / dt * 100)))
                root._cpuPrevBusy = busy
                root._cpuPrevTotal = total
            } else if (label.length > 3 && label.substring(0, 3) === "cpu") {
                var idx = label.substring(3)
                var p = prev[idx]
                var pct = 0
                if (p) {
                    var ddt = total - p.total
                    if (ddt > 0) pct = Math.max(0, Math.min(100, Math.round((busy - p.busy) / ddt * 100)))
                }
                prev[idx] = { busy: busy, total: total }
                perCore.push(pct)
            }
        }
        root._perCorePrev = prev
        root.perCoreLoad = perCore
        if (root._cpuPrevTotal > 0)
            root.cpuHistory = History.appendHistory(root.cpuHistory, Date.now(), root.cpuUsage,
                                                    root.historyWindowMs, root.historyMaxSamples)
    }

    // ── CPU GHz: max "cpu MHz" across cores in /proc/cpuinfo (FileView) ─────
    // Replaces the scaling_cur_freq sh loop — verified equal on this box
    // (4799 vs 4799.654 MHz at the same instant; both are the kernel's current
    // per-core frequency).
    FileView {
        id: cpuinfoFile
        path: "/proc/cpuinfo"
        watchChanges: false
        onTextChanged: root.parseCpuinfo(text())
    }

    function parseCpuinfo(raw) {
        var lines = String(raw).split("\n")
        var max = 0
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].indexOf("cpu MHz") !== 0) continue
            var v = parseFloat(lines[i].split(":")[1])
            if (isFinite(v) && v > max) max = v
        }
        if (max > 0) root.cpuGhz = +(max / 1000).toFixed(2)
    }

    // ── RAM + Swap from /proc/meminfo (FileView, no fork) ───────────────────
    // Matches this box's `free` (modern procps): used = MemTotal − MemAvailable
    // (kernel estimate; verified 4.95GB vs 4.95GB). Falls back to the classic
    // total − free − buffers − cached − sreclaimable if MemAvailable is absent.
    FileView {
        id: memFile
        path: "/proc/meminfo"
        watchChanges: false
        onTextChanged: root.parseMeminfo(text())
    }

    function parseMeminfo(raw) {
        var info = {}
        var lines = String(raw).split("\n")
        for (var i = 0; i < lines.length; i++) {
            var c = lines[i].indexOf(":")
            if (c < 0) continue
            info[lines[i].substring(0, c).trim()] = parseFloat(lines[i].substring(c + 1))
        }
        var total = info["MemTotal"] || 0
        if (total > 0) {
            var used = isFinite(info["MemAvailable"])
                ? Math.max(0, total - info["MemAvailable"])
                : Math.max(0, total - (info["MemFree"] || 0) - (info["Buffers"] || 0)
                                          - (info["Cached"] || 0) - (info["SReclaimable"] || 0))
            root.ramUsedGB = +(used / 1048576).toFixed(2)
            root.ramTotalGB = +(total / 1048576).toFixed(2)
            root.ramPct = +(used / total * 100).toFixed(1)
            root.memoryHistory = History.appendHistory(root.memoryHistory, Date.now(), root.ramPct,
                                                        root.historyWindowMs, root.historyMaxSamples)
        }
        var st = info["SwapTotal"] || 0
        var sf = info["SwapFree"] || 0
        root.swapTotalGB = +(st / 1048576).toFixed(2)
        root.swapUsedGB = +((st - sf) / 1048576).toFixed(2)
        root.swapPct = st > 0 ? +((st - sf) / st * 100).toFixed(1) : 0
    }

    // ── Disk: all real data filesystems (df → GiB) ─────────────────────────
    // Parses every mounted filesystem, drops pseudo/boot FS (tmpfs, vfat,
    // efivarfs, …), and exposes the rest as `disks[]` for the Storage card.
    // The root "/" entry also back-fills diskUsedTB/diskTotalTB/diskPct so the
    // deepcool LCD feed keeps working. df's size/used/avail are 1K-blocks →
    // /1048576 = GiB (the codebase's "GB"). New drives auto-appear.
    //
    // IMPORTANT: SplitParser emits one callback per line WITHOUT the trailing
    // newline — a multi-line `df` would otherwise collapse into one blob and
    // split("\n") would yield a single element. Re-append "\n" before splitting.
    Process {
        id: diskProc
        command: ["bash", "-c", "df --output=source,fstype,size,used,avail,pcent,target 2>/dev/null"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { diskProc.buffer += data + "\n" } }
        onRunningChanged: {
            if (!running && diskProc.buffer.trim().length) {
                var lines = diskProc.buffer.trim().split("\n")
                // pseudo / virtual / boot filesystems to skip — keep real data FS.
                var skip = { tmpfs:1, devtmpfs:1, ramfs:1, squashfs:1, overlay:1,
                    iso9660:1, efivarfs:1, vfat:1, fuseblk:1, autofs:1, mqueue:1,
                    hugetlbfs:1, "9p":1, fusectl:1, configfs:1, debugfs:1, sysfs:1,
                    proc:1, cgroup:1, cgroup2:1, nsfs:1, binfmt_misc:1, pstore:1,
                    securityfs:1, tracefs:1, rpc_pipefs:1, devpts:1 }
                var disks = []
                var rootEntry = null
                for (var i = 1; i < lines.length; i++) {
                    var f = lines[i].trim().split(/\s+/)
                    if (f.length < 7) continue
                    var fstype = f[1]
                    if (skip[fstype]) continue
                    var sizeK = parseFloat(f[2]), usedK = parseFloat(f[3]), availK = parseFloat(f[4])
                    if (isNaN(sizeK) || sizeK <= 0) continue
                    var pct = parseInt(f[5], 10)
                    var target = f.slice(6).join(" ")
                    var d = {
                        device: f[0], fstype: fstype, mount: target,
                        usedGB: +(usedK / 1048576).toFixed(1),
                        availGB: +(availK / 1048576).toFixed(1),
                        totalGB: +(sizeK / 1048576).toFixed(1),
                        pct: isNaN(pct) ? 0 : pct
                    }
                    disks.push(d)
                    if (target === "/") rootEntry = d
                }
                root.disks = disks
                if (rootEntry) {
                    root.diskUsedTB = +(rootEntry.usedGB / 1024).toFixed(2)
                    root.diskTotalTB = +(rootEntry.totalGB / 1024).toFixed(2)
                    root.diskPct = rootEntry.pct
                }
                diskProc.buffer = ""
            }
        }
    }

    // ── Aggregate everything → metrics.json ─────────────────────────────────
    // Sibling singletons (GpuService, ThermalService) resolve by bare name
    // within this module. Coolant is null in the feed when no sensor matched.
    function publish() {
        var m = {
            ts: Math.floor(Date.now() / 1000),
            cpu_temp: ThermalService.cpuTemp,
            cpu_usage: root.cpuUsage,
            cpu_per_core: root.perCoreLoad,
            cpu_ghz: root.cpuGhz,
            gpu_temp: GpuService.temp,
            gpu_usage: GpuService.util,
            gpu_vram_used_gb: GpuService.vramUsedGB,
            gpu_vram_total_gb: GpuService.vramTotalGB,
            gpu_power_w: GpuService.powerW,
            gpu_fan_pct: GpuService.fanPct,
            gpu_clock_mhz: GpuService.clockMHz,
            ram_used_gb: root.ramUsedGB,
            ram_total_gb: root.ramTotalGB,
            ram_pct: root.ramPct,
            coolant_temp: ThermalService.coolantAvailable ? ThermalService.coolantTemp : null,
            nvme_temp: ThermalService.nvmeTemp,
            disk_used_tb: root.diskUsedTB,
            disk_total_tb: root.diskTotalTB,
            disk_pct: root.diskPct,
            swap_used_gb: root.swapUsedGB,
            swap_total_gb: root.swapTotalGB,
            swap_pct: root.swapPct
        }
        var json = JSON.stringify(m)
        // Zero-fork write: FileView's setText goes through its write adapter
        // (same truncate+write semantics the old `printf >` had). The parent
        // dir (~/.cache/deepcool) is ensured once at startup by initProc.
        metricsFile.setText(json)
    }

    // ── 1s refresh + publish, ONLY while a consumer wants telemetry. publish()
    //    additionally requires the LCD (the Core tab binds properties directly,
    //    it doesn't read metrics.json). FileView reads are near-instant;
    //    publish() emits the previous tick's values (≤1s stale) — fine for an
    //    LCD. Disk is on its own slower timer below. ─────────────────────────
    Timer {
        interval: 1000
        running: root.telemetryWanted
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            // ASYNC re-reads; parsing happens in each view's onTextChanged
            // when the fresh content lands (see FRESHNESS CONTRACT above).
            statFile.reload()
            cpuinfoFile.reload()
            memFile.reload()
            if (root.lcdPresent) root.publish()   // emits ≤1 tick stale — fine for an LCD
        }
    }

    // Disk capacity changes slowly — refresh every 30s, not every tick.
    Timer {
        interval: 30000
        running: root.telemetryWanted
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!diskProc.running) diskProc.running = true }
    }
}
