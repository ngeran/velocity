/** Version: 1 — P2.3: the ONE metrics service. Absorbs SystemInfoService
 ** (fastfetch profile + overlay live metrics + geo), SystemMetricsService
 ** (1s /proc FileView engine, lsblk disks, deepcool-py feed, host identity),
 ** GpuService (GPU telemetry — now DIRECT properties, the runtime metrics.json
 ** round-trip is gone) and ThermalService (hwmon temps). **/
// =============================================================================
// MetricsService.qml — hardware profile + live telemetry + deepcool feed
// =============================================================================
//   STATIC PROFILE   fastfetch --format json   (CPU/GPU/OS/kernel/packages/disks)
//                    + DMI board identity + $SHELL       (refreshed on open)
//   LIVE METRICS     /proc via FileView (stat/cpuinfo/meminfo/uptime — ZERO
//                    forks per tick) + lsblk disks (30s) + hwmon temps (5s)
//   GPU              ONE long-running `nvidia-smi … -l 2` while leased (the
//                    spawn-per-tick prober is gone) + a bounded per-process
//                    query every other tick
//   DEEPCOOL FEED    ~/.cache/deepcool/metrics.json (deepcool-py watches this
//                    file) — published only while the LCD daemon is present
//   NETWORK / GEO    ip-api.com once per session (graceful "—" on failure)
//
//   LEASE — nothing polls without a consumer. Grant sources: the overlay's
//   shown-state (`active`), IPC `metrics lease <seconds>` (clamp ≤ 30s,
//   lib/lease.mjs), the dashboard Core tab (`coreVisible`, set by its Loader)
//   and the deepcool LCD probe (`lcdPresent`). Rings (cpuHistory/memoryHistory/
//   gpuHistory) sample only while telemetryWanted (Core tab or LCD).
//
//   History ring buffers are singleton-owned so charts survive the dashboard
//   Loader teardown on panel close.
//
//   Ex-GpuService names (temp/util/vram*/powerW/fanPct/clockMHz/present/
//   processes/gpuHistory) are live aliases of the prober fields — the settings
//   views read them unchanged through HostBridge.metrics.
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
import Quickshell
import Quickshell.Io
import "../lib/lease.mjs" as Lease
import "../lib/system-info.mjs" as Info
import "../lib/history.mjs" as History
import "../lib/storage.mjs" as Storage

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
    property var profileDisks: []           // [{dev,mount,usedLabel,totalLabel,pct}] — fastfetch rows
    property int osAgeDays: 0
    property string installDate: ""         // "2026-07-04"
    property string boardVendor: "—"        // system vendor, e.g. "ASUS"
    property string boardName: "—"          // board model, e.g. "TUF GAMING B650-E WIFI"
    property string chipset: "—"            // parsed chipset code, e.g. "X870E", "B650E"

    // =========================================================================
    // OVERLAY LIVE METRICS  (every 1s while leased)
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
    // LEASE — two bool consumers + the timed grant (lib/lease.mjs)
    // =========================================================================
    property real _leaseUntil: 0
    function extendLease(seconds) {
        var e = Lease.acquire(seconds, Date.now())
        if (e > root._leaseUntil) root._leaseUntil = e
    }
    // deepcool LCD daemon presence (pgrep, 60s) — an always-on feed consumer.
    property bool lcdPresent: false
    // Dashboard Core tab session (Loader Completed/Destruction sets it).
    property bool coreVisible: false
    // The 1s engine exists for exactly two file-feed consumers: the deepcool
    // LCD (external daemon) and the Core tab (binds properties directly).
    readonly property bool telemetryWanted: coreVisible || lcdPresent
    // Anything leased keeps the engine ticking.
    readonly property bool leased: active || telemetryWanted || root._leaseUntil > Date.now()

    // =========================================================================
    // CORE-TAB ENGINE  (ex-SystemMetricsService surface, names unchanged)
    // =========================================================================
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

    // ── deepcool metrics.json path (~/.cache/deepcool/metrics.json) ─────────
    // GenericCacheLocation is the SHARED ~/.cache (CacheLocation is app-specific
    // → ~/.cache/quickshell here). deepcool-py reads this exact path.
    property string metricsPath: StandardPaths.writableLocation(StandardPaths.GenericCacheLocation)
                                       .toString().replace("file://", "") + "/deepcool/metrics.json"

    // =========================================================================
    // GPU (ex-GpuService surface — direct reads, no file round-trip)
    // =========================================================================
    property string vendor: "nvidia"
    property bool _gpuSeen: false           // the prober answered at least once
    property var gpuProcesses: []           // [{pid,name,memMiB}] desc by mem, cap 6
    property int gpuMemUsedMiB: 0
    property int gpuMemTotalMiB: 0
    property real gpuFanPct: 0
    property real gpuClockMHz: 0

    // Aliases the settings views bind (unchanged names).
    readonly property string name: gpuName          // static — fastfetch profile
    readonly property real temp: gpuTempC           // °C
    readonly property real util: gpuUsagePct        // %
    readonly property real vramUsedGB: +(gpuMemUsedMiB / 1024).toFixed(2)
    readonly property real vramTotalGB: +(gpuMemTotalMiB / 1024).toFixed(2)
    readonly property real vramPct: vramTotalGB > 0
        ? +(vramUsedGB / vramTotalGB * 100).toFixed(1) : 0
    readonly property real powerW: gpuPowerW
    readonly property real fanPct: gpuFanPct
    readonly property real clockMHz: gpuClockMHz
    readonly property bool present: _gpuSeen
    readonly property var processes: gpuProcesses

    // ── 2-min rolling utilisation history — sampled only while a consumer
    // actually watches (idle prober output must not churn charts).
    property var gpuHistory: []

    // =========================================================================
    // THERMALS (ex-ThermalService surface — hwmon sysfs)
    // =========================================================================
    property real cpuTemp: 0          // °C
    property real nvmeTemp: 0         // °C
    property real coolantTemp: 0      // °C
    property bool coolantAvailable: false

    function _parseMilli(buf) {
        var v = parseInt((buf || "").trim(), 10)
        return (!isNaN(v) && v > 0) ? +(v / 1000).toFixed(1) : 0
    }

    // =========================================================================
    // CONTROL
    // =========================================================================
    function refresh() {
        root.loading = true
        ffProc.run()
        shellProc.run()
        boardProc.run()
        if (!root.leased) root.extendLease(5)   // one profile pass wants one live tick
    }

    function refreshStatic() {
        hostnameProc.run()
        userProc.run()
    }

    function refreshUptime() { uptimeFile.reload() }   // parse lands in onTextChanged

    function fmtUptime(sec) { return Info.formatUptime(sec) }

    function _applyPatch(target, patch, keys) {
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i]
            if (patch[k] !== undefined) target[k] = patch[k]
        }
    }

    Component.onCompleted: {
        console.log("[MetricsService] deepcool feed →", root.metricsPath)
        var dir = root.metricsPath.substring(0, root.metricsPath.lastIndexOf("/"))
        root.initProc.command = ["mkdir", "-p", dir]   // argv form — no shell, nothing to quote
        root.initProc.run()
        root.refreshStatic()
        root.refreshUptime()
        lcdProbe.run()
        console.log("[MetricsService] booted: leased=" + root.leased +
                    " lcd=" + root.lcdPresent + " core=" + root.coreVisible)
    }

    // =========================================================================
    // STATIC PROFILE PROBES
    // =========================================================================
    BoundedProcess {   // bounded: one-shot fastfetch profile (P8.1)
        id: ffProc
        command: ["fastfetch", "--format", "json", "--logo", "none"]
        onDone: function (out) {
            var raw = out.trim()
            if (raw) {
                try {
                    var p = Info.parseFastfetch(raw, Date.now())
                    // The lib's key is `disks`; the merged service reserves that
                    // name for the live lsblk rows — rename on intake.
                    if (p.disks !== undefined) root.profileDisks = p.disks
                    delete p.disks
                    root._applyPatch(root, p, [
                        "userName", "hostName",
                        "cpuModel", "cpuThreads", "cpuMaxGhz",
                        "gpuName", "gpuDriver", "gpuType", "gpuVendor",
                        "memTotalGiB",
                        "osName", "osCodename", "osVersion",
                        "kernelName", "kernelRelease", "arch",
                        "pkgAll", "pkgSystem", "pkgUser",
                        "installDate", "osAgeDays"
                    ])
                } catch (e) {
                    console.log("[MetricsService] fastfetch parse error:", e)
                }
            }
            root.loading = false
        }
    }

    // login shell — fastfetch mis-reports it (sees the launching wrapper), so
    // read $SHELL directly and basename it in QML.
    BoundedProcess {   // bounded: one-shot $SHELL read (P8.1)
        id: shellProc
        command: ["sh", "-c", "echo $SHELL"]
        onDone: function (out) {
            var s = out.trim()
            if (s) {
                var slash = s.lastIndexOf("/")
                root.shellName = slash >= 0 ? s.substring(slash + 1) : s
            }
        }
    }

    // Motherboard / chipset identity — DMI sysfs (fastfetch's default module set
    // has no Board block here).
    BoundedProcess {   // bounded: one-shot DMI read (P8.1)
        id: boardProc
        command: ["sh", "-c",
            "printf '%s|%s' \"$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)\" \"$(cat /sys/class/dmi/id/board_name 2>/dev/null)\""]
        onDone: function (out) {
            var b = Info.parseBoard(out)
            if (b) {
                if (b.vendor !== undefined) root.boardVendor = b.vendor
                if (b.name !== undefined) root.boardName = b.name
                if (b.chipset !== undefined) root.chipset = b.chipset
            }
        }
    }

    // =========================================================================
    // GEO — curl ip-api.com once per session; "—" on any failure
    // =========================================================================
    // BoundedProcess (C2) — a wedged resolver is exactly the hang class the
    // kill timer exists for. onLimit resolves geoDone so the once-per-session
    // gate never retries.
    BoundedProcess {
        id: geoProc
        timeoutMs: 10000   // curl --max-time 6 + margin; the timer is the backstop
        command: ["sh", "-c", "curl -s --max-time 6 'http://ip-api.com/json/?fields=city,country,countryCode' || true"]
        onDone: function(out, err, code) {
            root.geoDone = true
            var g = Info.parseGeo(out)   // null on offline / rate-limited / garbage
            if (g) {
                root.geoCity = g.city
                root.geoCountry = g.country
            }
        }
        onLimit: function(reason) { root.geoDone = true }
    }

    // =========================================================================
    // LIVE /proc READERS — FileView, ZERO forks per tick (FRESHNESS CONTRACT:
    // reload() is ASYNC; parse on textChanged, never a synchronous text()).
    // =========================================================================
    FileView { id: statFile;    path: "/proc/stat";    watchChanges: false
               onTextChanged: root.parseStat(text()) }
    FileView { id: cpuinfoFile; path: "/proc/cpuinfo"; watchChanges: false
               onTextChanged: root.parseCpuinfo(text()) }
    FileView { id: memFile;     path: "/proc/meminfo"; watchChanges: false
               onTextChanged: root.parseMeminfo(text()) }
    FileView { id: uptimeFile;  path: "/proc/uptime";  watchChanges: false
               onTextChanged: root.parseUptime(text()) }

    // ── CPU aggregate + per-core (ex-SystemMetricsService.parseStat) ────────
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
        if (root.telemetryWanted && root._cpuPrevTotal > 0)
            root.cpuHistory = History.appendHistory(root.cpuHistory, Date.now(), root.cpuUsage,
                                                    root.historyWindowMs, root.historyMaxSamples)
    }

    // ── CPU GHz: max "cpu MHz" across cores in /proc/cpuinfo ────────────────
    // Replaces the scaling_cur_freq sh loop — verified equal on this box.
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

    // ── RAM + Swap (matches this box's `free`: used = MemTotal − MemAvailable,
    // classic fallback when MemAvailable is absent) ──────────────────────────
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
            root.memUsedGiB = +(used / 1048576).toFixed(2)
            root.memPct = root.ramPct
            if (root.telemetryWanted)
                root.memoryHistory = History.appendHistory(root.memoryHistory, Date.now(), root.ramPct,
                                                            root.historyWindowMs, root.historyMaxSamples)
        }
        var st = info["SwapTotal"] || 0
        var sf = info["SwapFree"] || 0
        root.swapTotalGB = +(st / 1048576).toFixed(2)
        root.swapUsedGB = +((st - sf) / 1048576).toFixed(2)
        root.swapPct = st > 0 ? +((st - sf) / st * 100).toFixed(1) : 0
    }

    // ── Uptime (overlay string + Core pane string from the same read) ───────
    function parseUptime(raw) {
        var secs = parseFloat(String(raw).split(" ")[0])
        if (isNaN(secs) || secs <= 0) return
        root.uptimeSeconds = secs
        root.uptimeStr = Info.formatUptime(secs)
        if (root.coreVisible) root.uptime = root._formatUptime(secs)
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

    // =========================================================================
    // GPU — ONE long-running `nvidia-smi -l 2` while leased (P2.3: the
    // spawn-per-tick prober is gone; the lease binding stops the process).
    // Fields can be [N/A] on some drivers → NaN → 0.
    // =========================================================================
    Process {   // unbounded-ok: the leased `nvidia-smi -l 2` long-runner —
        id: gpuLoop   // lifecycle bound to root.leased (onLeasedChanged stops it)
        command: ["nvidia-smi",
                  "--query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw,fan.speed,clocks.gr",
                  "--format=csv,noheader,nounits", "-l", "2"]
        running: false
        stdout: SplitParser {
            onRead: function(data) {
                var p = Info.parseNvidiaSmi(data)
                if (!p) return
                if (p.tempC !== undefined) root.gpuTempC = p.tempC
                if (p.usagePct !== undefined) root.gpuUsagePct = p.usagePct
                if (p.memUsedMiB !== undefined) root.gpuMemUsedMiB = p.memUsedMiB
                if (p.memTotalMiB !== undefined) root.gpuMemTotalMiB = p.memTotalMiB
                if (p.powerW !== undefined) root.gpuPowerW = p.powerW
                if (p.fanPct !== undefined) root.gpuFanPct = p.fanPct
                if (p.clockMHz !== undefined) root.gpuClockMHz = p.clockMHz
                if (p.seen) {
                    root._gpuSeen = true
                    if (root.telemetryWanted)
                        root.gpuHistory = History.appendHistory(root.gpuHistory, Date.now(),
                                                                root.gpuUsagePct, 120000, 130)
                }
            }
        }
    }
    // Lease edges start/stop the long-runner (binding flip → SIGTERM).
    onLeasedChanged: gpuLoop.running = root.leased

    // Per-process GPU consumers (nvtop-equivalent) — bounded one-shot every
    // other tick; no rows is a valid answer (nothing using the GPU).
    BoundedProcess {
        id: gpuAppsProc
        timeoutMs: 6000
        command: ["nvidia-smi",
                  "--query-compute-apps=pid,process_name,used_memory",
                  "--format=csv,noheader,nounits"]
        onDone: function(out, err, code) {
            root.gpuProcesses = Info.parseGpuApps(out)
        }
    }

    // =========================================================================
    // THERMALS — hwmon sysfs (ex-ThermalService probes verbatim)
    // =========================================================================
    // ── CPU package temp: coretemp/k10temp, max sensor ──────────────────────
    BoundedProcess {   // bounded: one-shot hwmon read (P8.1)
        id: cpuTempProc
        command: ["sh", "-c",
            "for d in /sys/class/hwmon/hwmon*; do n=$(cat \"$d/name\" 2>/dev/null); " +
            "case \"$n\" in coretemp|k10temp) for i in $(seq 1 20); do " +
            "cat \"$d/temp${i}_input\" 2>/dev/null; done;; esac; done | sort -n | tail -1"]
        onDone: function (out) {
            if (out.trim().length) root.cpuTemp = root._parseMilli(out)
        }
    }

    // ── NVMe temp: max over nvme hwmons ─────────────────────────────────────
    BoundedProcess {   // bounded: one-shot hwmon read (P8.1)
        id: nvmeProc
        command: ["sh", "-c",
            "for d in /sys/class/hwmon/hwmon*; do [ \"$(cat \"$d/name\" 2>/dev/null)\" = nvme ] " +
            "&& cat \"$d/temp1_input\" 2>/dev/null; done | sort -n | tail -1"]
        onDone: function (out) {
            if (out.trim().length) root.nvmeTemp = root._parseMilli(out)
        }
    }

    // ── Coolant temp: best-effort label scan (usually unavailable) ──────────
    BoundedProcess {   // bounded: one-shot hwmon read (P8.1)
        id: coolantProc
        command: ["sh", "-c",
            "for d in /sys/class/hwmon/hwmon*; do for i in 1 2 3 4 5 6; do " +
            "l=$(cat \"$d/temp${i}_label\" 2>/dev/null); case \"$l\" in " +
            "*water*|*coolant*|*liquid*|*aio*) cat \"$d/temp${i}_input\" 2>/dev/null;; esac; done; done | sort -n | tail -1"]
        onDone: function (out) {
            var raw = out.trim()
            if (raw.length) {
                var v = parseInt(raw, 10)
                if (!isNaN(v) && v > 0) {
                    root.coolantTemp = +(v / 1000).toFixed(1)
                    root.coolantAvailable = true
                }
            }
        }
    }

    function _refreshTemps() {
        cpuTempProc.run()
        nvmeProc.run()
        coolantProc.run()
    }

    // Temps move slowly; 5s is enough and keeps the hwmon scan cheap.
    Timer {
        interval: 5000
        running: root.leased
        repeat: true
        triggeredOnStart: true
        onTriggered: root._refreshTemps()
    }

    // Hung-process reaper — a stuck hwmon read would silently stop the feed
    // forever (guards skip while a Process reports running).
    Timer {
        interval: 15000
        repeat: true
        running: root.leased
        onTriggered: {
            if (cpuTempProc.running)  cpuTempProc.running = false
            if (nvmeProc.running)     nvmeProc.running = false
            if (coolantProc.running)  coolantProc.running = false
        }
    }

    // =========================================================================
    // DISKS — all real data filesystems (lsblk via lib/storage.mjs; same ONE
    // parse the nikos.storage plugin uses — synced copy). The root "/" row
    // back-fills diskUsedTB/diskTotalTB/diskPct for the deepcool feed.
    // SplitParser emits per-chunk callbacks WITHOUT the trailing newline —
    // re-join before Storage.parseJson.
    // =========================================================================
    BoundedProcess {   // bounded: one-shot lsblk survey (P8.1)
        id: diskProc
        command: ["lsblk", "-J", "-b",
            "-o", "NAME,TYPE,SIZE,FSTYPE,FSUSED,FSAVAIL,FSUSE%,MOUNTPOINTS,MODEL,TRAN,ROTA,RM,HOTPLUG"]
        onDone: function (out) {
            if (out.trim().length) {
                var json = Storage.parseJson(out)
                var rows = json ? Storage.parseFilesystems(json) : []
                root.disks = rows
                for (var i = 0; i < rows.length; i++) {
                    if (rows[i].mount === "/") {
                        root.diskUsedTB = +(rows[i].usedGB / 1024).toFixed(2)
                        root.diskTotalTB = +(rows[i].totalGB / 1024).toFixed(2)
                        root.diskPct = rows[i].pct
                        break
                    }
                }
            }
        }
    }

    // Disk capacity changes slowly — 30s, not every tick.
    Timer {
        interval: 30000
        running: root.leased
        repeat: true
        triggeredOnStart: true
        onTriggered: diskProc.run()
    }

    // =========================================================================
    // DEEPCOOL FEED — ~/.cache/deepcool/metrics.json (deepcool-py watches this
    // file). Published only while the LCD daemon is present; the Core tab binds
    // properties directly, it doesn't read the file. GPU fields come from THIS
    // service's prober now (ex-GpuService indirection is gone).
    // =========================================================================
    BoundedProcess {   // bounded: one-shot pgrep (P8.1)
        id: lcdProbe   // [d]eepcool regex self-match guard: pgrep -f scans full
        command: ["sh", "-c",   // command lines; anything probing THIS file's path
                  "pgrep -f '[d]eepcool' >/dev/null 2>&1"]   // would read as the LCD daemon and light the feed up.
        onDone: function (out, err, code) { root.lcdPresent = (code === 0) }
    }
    Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: false   // Component.onCompleted probes once at boot
        onTriggered: lcdProbe.run()
    }

    // metrics.json via FileView's WRITE path (setText) — truncate+write, zero
    // forks. The parent dir is ensured once at startup by initProc.
    FileView {
        id: metricsFile
        path: root.metricsPath
        printErrors: false
    }
    property var initProc: BoundedProcess { command: ["mkdir", "-p"] }   // bounded: one-shot mkdir (P8.1)

    function publish() {
        var m = {
            ts: Math.floor(Date.now() / 1000),
            cpu_temp: root.cpuTemp,
            cpu_usage: root.cpuUsage,
            cpu_per_core: root.perCoreLoad,
            cpu_ghz: root.cpuGhz,
            gpu_temp: root.temp,
            gpu_usage: root.util,
            gpu_vram_used_gb: root.vramUsedGB,
            gpu_vram_total_gb: root.vramTotalGB,
            gpu_power_w: root.powerW,
            gpu_fan_pct: root.fanPct,
            gpu_clock_mhz: root.clockMHz,
            ram_used_gb: root.ramUsedGB,
            ram_total_gb: root.ramTotalGB,
            ram_pct: root.ramPct,
            coolant_temp: root.coolantAvailable ? root.coolantTemp : null,
            nvme_temp: root.nvmeTemp,
            disk_used_tb: root.diskUsedTB,
            disk_total_tb: root.diskTotalTB,
            disk_pct: root.diskPct,
            swap_used_gb: root.swapUsedGB,
            swap_total_gb: root.swapTotalGB,
            swap_pct: root.swapPct
        }
        metricsFile.setText(JSON.stringify(m))
    }

    // =========================================================================
    // HOST IDENTITY — hostname / user (static per boot, one-shot reads) +
    // uptime string (parsed from the same /proc/uptime FileView as the
    // overlay's). No board/DMI/kernel fields here — the static profile above
    // owns board identity for FastfetchOverlay.
    // =========================================================================
    property string hostname: "unknown"
    property string uptime: "—"

    BoundedProcess {   // bounded: one-shot hostname read (P8.1)
        id: hostnameProc
        command: ["sh", "-c", "hostnamectl hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || hostname 2>/dev/null"]
        onDone: function (out) {
            if (out.length > 0) root.hostname = out.trim()
        }
    }

    BoundedProcess {   // bounded: one-shot whoami (P8.1)
        id: userProc
        command: ["sh", "-c", "whoami"]
        onDone: function (out) {
            var u = out.trim()
            if (u.length > 0 && root.userName === "")
                root.userName = u.charAt(0).toUpperCase() + u.slice(1)
        }
    }

    // =========================================================================
    // 1s ENGINE TICK — lease-gated. FileView reloads are ASYNC (parse lands in
    // each onTextChanged); publish() emits the previous tick's values (≤1s
    // stale — fine for an LCD). The GPU apps probe rides every other tick.
    // =========================================================================
    property int _tickN: 0
    Timer {
        id: liveTimer
        interval: 1000
        repeat: true
        running: root.leased
        triggeredOnStart: true
        onTriggered: {
            // A timed grant expiring is not a property write — the `leased`
            // binding never re-evaluates on its own. Notice the death here and
            // clear the grant: the write notifies, `leased` flips false, this
            // timer and the gpuLoop stop (the old service's self-clear idiom).
            if (!(root.active || root.telemetryWanted || root._leaseUntil > Date.now())) {
                root._leaseUntil = 0
                return
            }
            statFile.reload()
            cpuinfoFile.reload()
            memFile.reload()
            uptimeFile.reload()
            if (root.lcdPresent) root.publish()
            root._tickN++
            if (root._tickN % 2 === 0 && !gpuAppsProc.running) gpuAppsProc.run()
        }
    }
}
