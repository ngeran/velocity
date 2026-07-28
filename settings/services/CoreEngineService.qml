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
// Process + SplitParser + Timer idiom mirrors SysInfoService.qml; JSON write
// (printf > path with single-quote escaping) mirrors SettingsConfigService.qml.
//
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
import Quickshell.Io

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

    // ── internal CPU delta state ────────────────────────────────────────────
    property real _cpuPrevBusy: 0
    property real _cpuPrevTotal: 0
    property var _perCorePrev: ({})

    // ── metrics.json path (~/.cache/deepcool/metrics.json) ──────────────────
    // GenericCacheLocation is the SHARED ~/.cache (CacheLocation is app-specific
    // → ~/.cache/quickshell here). deepcool-py reads this exact path.
    property string metricsPath: StandardPaths.writableLocation(StandardPaths.GenericCacheLocation)
                                       .toString().replace("file://", "") + "/deepcool/metrics.json"

    property Process publisher: Process {
        command: []; running: false
        // Rate-limited failure log: publish() fires every ~1s; if the metrics.json
        // write keeps failing (e.g. perms), surface it via CommandService at most
        // once per 10s instead of spamming the log every tick.
        property real _lastFailLogMs: 0
        onExited: function(code) {
            if (code !== 0 && Date.now() - publisher._lastFailLogMs > 10000) {
                publisher._lastFailLogMs = Date.now()
                CommandService.pushLog("[CoreEngine] publish failed exit=" + code, "error")
            }
        }
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

    // ── CPU aggregate + per-core from one /proc/stat read ───────────────────
    Process {
        id: cpuProc
        // read-builtin filter (not `grep`): one sh fork instead of sh+grep.
        // Emits the same `cpu …` lines (one per line) so the per-core parser
        // below is unchanged. Verified byte-identical to `grep '^cpu'`.
        command: ["sh", "-c", "while IFS= read -r l; do case \"$l\" in cpu*) printf '%s\\n' \"$l\";; esac; done < /proc/stat"]
        property string buffer: ""
        // SplitParser emits each line WITHOUT its newline; re-add it so the
        // multi-line buffer keeps line boundaries (the single-line services in
        // SysInfoService don't need this, but the per-core parse does).
        stdout: SplitParser { onRead: function(data) { cpuProc.buffer += data + "\n" } }
        onRunningChanged: {
            if (!running && cpuProc.buffer.length) {
                var lines = cpuProc.buffer.trim().split("\n")
                var perCore = []
                var prev = root._perCorePrev
                for (var i = 0; i < lines.length; i++) {
                    var f = lines[i].trim().split(/\s+/)
                    if (f.length < 5) continue
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
                cpuProc.buffer = ""
            }
        }
    }

    // ── CPU GHz: max scaling_cur_freq across cores (kHz → GHz) ──────────────
    Process {
        id: ghzProc
        // read-builtin per core (not `cat`): used to fork `cat` once per core
        // (N+1/tick ≈ 17/tick on 16 cores) — the single biggest forker in this
        // service. Now a single sh fork. `read v < "$f"` parses scaling_cur_freq
        // identically to `cat` (verified); same single-integer echo → parser
        // unchanged.
        command: ["sh", "-c",
            "m=0; for f in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq; do " +
            "[ -r \"$f\" ] || continue; read v < \"$f\"; [ \"$v\" -gt \"$m\" ] && m=$v; done; echo \"$m\""]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { ghzProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                var v = parseInt((ghzProc.buffer || "").trim(), 10)
                if (!isNaN(v) && v > 0) root.cpuGhz = +(v / 1000000).toFixed(2)
                ghzProc.buffer = ""
            }
        }
    }

    // ── RAM + Swap from one `free` call (KiB → GB) ──────────────────────────
    Process {
        id: memProc
        command: ["bash", "-c",
            "free | awk '/^Mem:/{mu=$3/1048576; mt=$2/1048576; mp=($2>0?$3/$2*100:0)} " +
            "/^Swap:/{su=$3/1048576; st=$2/1048576; sp=($2>0?$3/$2*100:0)} " +
            "END{printf \"%.2f %.2f %.1f %.2f %.2f %.1f\", mu,mt,mp,su,st,sp}'"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { memProc.buffer += data } }
        onRunningChanged: {
            if (!running && memProc.buffer.trim().length) {
                var f = memProc.buffer.trim().split(/\s+/)
                var mu = parseFloat(f[0]), mt = parseFloat(f[1]), mp = parseFloat(f[2])
                var su = parseFloat(f[3]), st = parseFloat(f[4]), sp = parseFloat(f[5])
                if (!isNaN(mu)) {
                    root.ramUsedGB = mu; root.ramTotalGB = mt; root.ramPct = mp
                    root.swapUsedGB = su; root.swapTotalGB = st; root.swapPct = sp
                }
                memProc.buffer = ""
            }
        }
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
    // split("\n") would yield a single element. Re-append "\n" (same trick
    // cpuProc uses for /proc/stat) before splitting.
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
        // printf to the path; single-quote-escape the JSON the same way
        // SettingsConfigService.qml does. The parent dir (~/.cache/deepcool) is
        // ensured once at startup by initProc, so no per-tick `mkdir` fork.
        root.publisher.command = ["sh", "-c",
            "printf '%s' '" + json.replace(/'/g, "'\\''") + "' > '" + root.metricsPath + "'"]
        root.publisher.running = true
    }

    // ── 1s refresh + publish. Readers are async; publish() emits the previous
    //    tick's values (≤1s stale) — fine for an LCD. Guards prevent re-entry
    //    if a reader outruns 1s. Disk is on its own slower timer below. ───────
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!cpuProc.running) cpuProc.running = true
            if (!ghzProc.running) ghzProc.running = true
            if (!memProc.running) memProc.running = true
            root.publish()
        }
    }

    // Disk capacity changes slowly — refresh every 30s, not every tick.
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!diskProc.running) diskProc.running = true }
    }
}
