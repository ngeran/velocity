/** Version: 2.0 - Themed system-info telemetry + H7 metrics publisher **/
// =============================================================================
// SystemInfoService.qml — data backbone for the System Info dashboard AND the
// ONE cross-process metrics producer (H7).
// =============================================================================
// Aggregates a hardware/OS profile + live metrics for the FastfetchOverlay
// (the "SYSTEM INFO" popup opened from the logo). The overlay stays pure
// layout; all gathering/parsing lives here.
//
//   STATIC PROFILE   fastfetch --format json   (CPU/GPU/OS/kernel/packages/disks)
//   LIVE METRICS     /proc/meminfo + /proc/uptime + /proc/stat + df + nvidia-smi
//                    (polled ONLY while a lease is live — see LEASE below)
//   NETWORK / GEO    ip-api.com once per session (graceful "—" on failure)
//   METRICS FILE     $XDG_RUNTIME_DIR/velocity/metrics.json (atomic tmp+mv)
//                    — settings' Core GPU sections and the dashboard System
//                    Pulse card read it (FileView) and renew the lease every
//                    10s while visible. Nothing polls without a lease.
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/lease.mjs" as Lease

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
    property string boardVendor: "—"        // system vendor, e.g. "ASUS"
    property string boardName: "—"          // board model, e.g. "TUF GAMING B650-E WIFI"
    property string chipset: "—"            // parsed chipset code, e.g. "X870E", "B650E"

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

    // ── LEASE (H7) — live polling happens only while a consumer holds one ──
    // Two grant sources: the overlay's shown-state (`active`) and IPC
    // `metrics lease <seconds>` (clamped ≤ 30s, bar/lib/lease.mjs). Settings
    // renewers tick every 10s, so a 30s grant outlives one missed renewal.
    // A shorter grant never shortens a live lease (max wins). The poll timer
    // self-clears: on the first tick past expiry it zeroes _leaseUntil, which
    // flips its own running binding false — no watchdog timer needed.
    property real _leaseUntil: 0
    function extendLease(seconds) {
        var e = Lease.acquire(seconds, Date.now())
        if (e > root._leaseUntil) root._leaseUntil = e
    }
    function _leaseLive() { return root.active || root._leaseUntil > Date.now() }

    // ── METRICS FILE (H7) — aggregate snapshot for cross-process readers ────
    // {schema:1, ts, cpu:{pct}, mem:{usedB,totalB},
    //  gpu:null|{pct,memUsedB,memTotalB,tempC,powerW,fanPct,clockMHz,processes},
    //  disk:{usedB,totalB}}
    // gpu.processes = per-process compute consumers (moved here from settings'
    // GpuService so nvidia-smi is shelled from exactly ONE file repo-wide).
    // Field set is a superset of the ledger schema: powerW/fanPct/clockMHz/
    // processes/disk are additive (H4's card renders disk; the Core GPU
    // sections keep fan/clock/process rows alive through the file).
    readonly property string _runtimeDir:
        (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/" + (Quickshell.env("UID") || "1000"))
        + "/velocity"
    property bool _gpuSeen: false           // nvidia-smi answered at least once
    property var gpuProcesses: []           // [{pid,name,memMiB}] desc by mem, cap 6
    property int gpuMemUsedMiB: 0
    property int gpuMemTotalMiB: 0
    property real gpuFanPct: 0
    property real gpuClockMHz: 0

    // CPU% delta state — /proc/stat is cumulative jiffies; pct needs the
    // previous sample (same math SystemMetricsService runs settings-side).
    property real _cpuPrevBusy: 0
    property real _cpuPrevTotal: 0
    property int cpuPct: 0                  // 0..100, 0 until the 2nd sample
    property real diskUsedB: 0
    property real diskTotalB: 0

    // =========================================================================
    // CONTROL
    // =========================================================================
    function refresh() {
        root.loading = true
        if (!ffProc.running) ffProc.running = true
        if (!shellProc.running) shellProc.running = true
        if (!boardProc.running) boardProc.running = true
        root.pollLive()
        if (!root.geoDone) geoProc.run()   // run() no-ops while busy — never drops the call
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

    // Filter out generic placeholder board names SMBIOS leaves when unset.
    function _cleanBoardName(s) {
        if (!s) return ""
        var low = s.toLowerCase().trim()
        var junk = ["default string", "to be filled by o.e.m.",
                    "to be filled by o.e.m", "base board product name",
                    "system product name", "system board product name",
                    "not specified", "unknown", "none"]
        if (junk.indexOf(low) >= 0) return ""
        return s.trim()
    }

    // Extract a chipset code: optional A/B/X/H/Z prefix, 3 digits, optional -?E
    // suffix. Covers AMD (X870E, B650E, A620, X670, B550…) and Intel (Z790, B760…).
    function _parseChipset(s) {
        if (!s) return ""
        var m = s.match(/[ABXHZ]\d{3}-?E?/i)
        if (!m) return ""
        return m[0].replace("-", "").toUpperCase()
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

    Process {   // unbounded-ok: one-shot local command — timeout migration queued
        id: ffProc
        property string buffer: ""
        command: ["fastfetch", "--format", "json", "--logo", "none"]
        stdout: SplitParser { onRead: function(data) { ffProc.buffer += data + "\n" } }
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
    Process {   // unbounded-ok: trivial local check — no hang risk
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
    // Motherboard / chipset identity — DMI sysfs (fastfetch's default module set
    // has no Board block here, so read the kernel SMBIOS exposure directly:
    // sys_vendor + board_name; the chipset is parsed out of the board name).
    // =========================================================================
    Process {   // unbounded-ok: one-shot local read (sysfs/proc) — no hang or flood risk
        id: boardProc
        property string buffer: ""
        command: ["sh", "-c",
            "printf '%s|%s' \"$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)\" \"$(cat /sys/class/dmi/id/board_name 2>/dev/null)\""]
        stdout: SplitParser { onRead: function(data) { boardProc.buffer += data + "\n" } }
        onRunningChanged: if (!running) {
            var raw = boardProc.buffer
            boardProc.buffer = ""
            if (raw && raw.length > 0) {
                var parts = raw.split("|")
                var sysv = (parts[0] || "").trim()
                var name = root._cleanBoardName(parts[1] || "")
                if (sysv.length > 0) root.boardVendor = sysv
                if (name.length > 0) root.boardName = name
                var cs = root._parseChipset(name)
                if (cs.length > 0) root.chipset = cs
            }
        }
    }

    // =========================================================================
    // LIVE METRICS — /proc/meminfo + /proc/uptime + /proc/stat + df in one read
    // =========================================================================
    Process {   // unbounded-ok: one-shot local read (sysfs/proc) — no hang or flood risk
        id: liveProc
        property string buffer: ""
        command: ["sh", "-c", "cat /proc/meminfo /proc/uptime; head -1 /proc/stat; df -kP /"]
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
                // cumulative CPU jiffies (H7: cross-process cpu.pct)
                var cs = ln.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
                if (cs) {
                    var user = +cs[1], nice = +cs[2], sys = +cs[3], idle = +cs[4]
                    var iow = +cs[5], irq = +cs[6], sirq = +cs[7], steal = +cs[8]
                    var busy = user + nice + sys + irq + sirq + steal
                    var total = busy + idle + iow
                    var dBusy = busy - root._cpuPrevBusy
                    var dTotal = total - root._cpuPrevTotal
                    // First tick after start has no baseline (_cpuPrev* are 0):
                    // publishing then would emit the since-boot average as cpu.pct.
                    if (dTotal > 0 && root._cpuPrevTotal > 0)
                        root.cpuPct = Math.max(0, Math.min(100, Math.round(dBusy / dTotal * 100)))
                    root._cpuPrevBusy = busy
                    root._cpuPrevTotal = total
                    continue
                }
                // root-fs capacity for the metrics file (df -kP: POSIX, kB units)
                var df = ln.match(/^[^\s]+\s+(\d+)\s+(\d+)\s+\d+\s+\d+%\s+\/$/)
                if (df) {
                    root.diskTotalB = +df[1] * 1024
                    root.diskUsedB = +df[2] * 1024
                }
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
            root._publishMetrics()
        }
    }

    // GPU temp/power/usage/vram/fan/clock (NVIDIA) — the ONE nvidia-smi
    // telemetry fork in the repo (H7): settings' GpuService now reads the
    // metrics file instead of shelling out itself. Fields can be [N/A] on
    // some drivers → NaN → 0.
    Process {   // unbounded-ok: one-shot local command — timeout migration queued
        id: nvidiaProc
        command: ["nvidia-smi",
                  "--query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw,fan.speed,clocks.gr",
                  "--format=csv,noheader,nounits"]
        stdout: SplitParser {
            onRead: function(data) {
                var s = (data || "").trim()
                if (!s) return
                var f = s.split("\n")[0].split(",")
                var t = parseInt(f[0], 10), u = parseInt(f[1], 10)
                var mu = parseInt(f[2], 10), mt = parseInt(f[3], 10)
                var p = parseFloat(f[4]), fan = parseFloat(f[5]), clk = parseFloat(f[6])
                if (!isNaN(t)) root.gpuTempC = t
                if (!isNaN(u)) root.gpuUsagePct = u
                if (!isNaN(mu)) root.gpuMemUsedMiB = mu
                if (!isNaN(mt)) root.gpuMemTotalMiB = mt
                if (!isNaN(p)) root.gpuPowerW = Math.round(p * 100) / 100
                if (!isNaN(fan)) root.gpuFanPct = fan
                if (!isNaN(clk)) root.gpuClockMHz = clk
                if (!isNaN(t) || !isNaN(mt)) root._gpuSeen = true
            }
        }
    }

    // Per-process GPU consumers (nvtop-equivalent) — moved here from settings'
    // GpuService (H7): same parse, one repo-wide nvidia-smi file. No rows is
    // a valid answer (nothing using the GPU) → empty list.
    BoundedProcess {
        id: gpuAppsProc
        timeoutMs: 6000
        command: ["nvidia-smi",
                  "--query-compute-apps=pid,process_name,used_memory",
                  "--format=csv,noheader,nounits"]
        onDone: function(out, err, code) {
            var lines = (out || "").trim().split("\n")
            var procs = []
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i]
                if (!line.trim()) continue
                var parts = line.split(",")
                if (parts.length < 3) continue
                var pid = parseInt(parts[0].trim(), 10)
                var mem = parseFloat(parts[parts.length - 1].trim())
                var pathStr = parts.slice(1, -1).join(",").trim()
                var base = pathStr ? pathStr.split("/").pop() : "process"
                if (pid && !isNaN(mem)) procs.push({ pid: pid, name: base, memMiB: mem })
            }
            procs.sort(function(a, b) { return b.memMiB - a.memMiB })
            root.gpuProcesses = procs.slice(0, 6)
        }
    }

    // =========================================================================
    // GEO — curl ip-api.com once per session; "—" on any failure
    // =========================================================================
    // BoundedProcess (C2: the TODO migration) — curl self-bounds at 6s but a
    // wedged resolver is exactly the hang class the kill timer exists for.
    // onLimit resolves geoDone so the once-per-session gate never retries.
    BoundedProcess {
        id: geoProc
        timeoutMs: 10000   // curl --max-time 6 + margin; the timer is the backstop
        command: ["sh", "-c", "curl -s --max-time 6 'http://ip-api.com/json/?fields=city,country,countryCode' || true"]
        onDone: function(out, err, code) {
            root.geoDone = true
            try {
                var j = JSON.parse(out.trim())
                if (j && !j.error && j.city) {
                    root.geoCity = j.city
                    root.geoCountry = j.country || ""
                }
            } catch (e) {
                // offline / rate-limited / blocked — keep "—"
            }
        }
        onLimit: function(reason) { root.geoDone = true }
    }

    // =========================================================================
    // METRICS FILE PUBLISHER (H7) — atomic tmp+mv after every live tick
    // =========================================================================
    BoundedProcess {
        id: metricsWriter
        timeoutMs: 5000
    }
    function _publishMetrics() {
        var gpu = null
        if (root._gpuSeen) {
            gpu = {
                pct: root.gpuUsagePct,
                memUsedB: root.gpuMemUsedMiB * 1048576,
                memTotalB: root.gpuMemTotalMiB * 1048576,
                tempC: root.gpuTempC,
                powerW: root.gpuPowerW,
                fanPct: root.gpuFanPct,
                clockMHz: root.gpuClockMHz,
                processes: root.gpuProcesses
            }
        }
        var payload = JSON.stringify({
            schema: 1,
            ts: Date.now(),
            cpu: { pct: root.cpuPct },
            mem: { usedB: Math.round(root.memUsedGiB * 1073741824),
                   totalB: Math.round(root.memTotalGiB * 1073741824) },
            gpu: gpu,
            disk: { usedB: Math.round(root.diskUsedB), totalB: Math.round(root.diskTotalB) }
        })
        // positional argv ($1 dir, $2 payload) — the T23a "$0" lesson
        metricsWriter.command = ["sh", "-c",
            "mkdir -p -- \"$1\" && printf '%s' \"$2\" > \"$1/metrics.json.tmp\" && mv -f \"$1/metrics.json.tmp\" \"$1/metrics.json\"",
            "sh", root._runtimeDir, payload]
        metricsWriter.run()
    }

    // =========================================================================
    // LIVE POLL TIMER — lease-gated (H7). Two grant sources: the overlay's
    // shown-state and the IPC lease. Polls every 2s while EITHER is live;
    // the first tick past lease expiry zeroes _leaseUntil, which flips this
    // timer's own running binding false — no watchdog, no orphan polling.
    // =========================================================================
    Timer {
        id: liveTimer
        interval: 2000
        repeat: true
        running: root.active || root._leaseUntil > 0
        onTriggered: {
            if (!root._leaseLive()) { root._leaseUntil = 0; return }
            root.pollLive()
            if (!gpuAppsProc.running) gpuAppsProc.run()
        }
    }
}
