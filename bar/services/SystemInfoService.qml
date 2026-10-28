/** Version: 2.0 - Themed system-info telemetry + H7 metrics publisher **/
// =============================================================================
// SystemInfoService.qml — data backbone for the System Info dashboard AND the
// ONE cross-process metrics producer (H7).
// =============================================================================
// Aggregates a hardware/OS profile + live metrics for the FastfetchOverlay
// (the "SYSTEM INFO" popup opened from the logo). The overlay stays pure
// layout, the service stays IO + state — every parser/format lives in
// lib/system-info.mjs (node-tested, I8); the Process handlers below just
// apply its patches (undefined fields keep the previous value).
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
import "../lib/system-info.mjs" as Info

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
    // FORMAT HELPERS  (public surface kept; implementations live in the lib)
    // =========================================================================
    function fmtUptime(sec) { return Info.formatUptime(sec) }

    function _applyPatch(target, patch, keys) {
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i]
            if (patch[k] !== undefined) target[k] = patch[k]
        }
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
                    root._applyPatch(root, Info.parseFastfetch(raw, Date.now()), [
                        "userName", "hostName",
                        "cpuModel", "cpuThreads", "cpuMaxGhz",
                        "gpuName", "gpuDriver", "gpuType", "gpuVendor",
                        "memTotalGiB",
                        "osName", "osCodename", "osVersion",
                        "kernelName", "kernelRelease", "arch",
                        "pkgAll", "pkgSystem", "pkgUser",
                        "disks", "installDate", "osAgeDays"
                    ])
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
            var b = Info.parseBoard(raw)
            if (b) {
                if (b.vendor !== undefined) root.boardVendor = b.vendor
                if (b.name !== undefined) root.boardName = b.name
                if (b.chipset !== undefined) root.chipset = b.chipset
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
            var text = liveProc.buffer
            liveProc.buffer = ""
            var r = Info.parseLiveMetrics(text, root._cpuPrevBusy, root._cpuPrevTotal)
            if (r.memTotalGiB !== undefined) root.memTotalGiB = r.memTotalGiB
            if (r.memUsedGiB !== undefined) root.memUsedGiB = r.memUsedGiB
            if (r.memPct !== undefined) root.memPct = r.memPct
            if (r.uptimeSeconds !== undefined) {
                root.uptimeSeconds = r.uptimeSeconds
                root.uptimeStr = r.uptimeStr
            }
            if (r.cpuPct !== undefined) root.cpuPct = r.cpuPct
            root._cpuPrevBusy = r.prevBusy        // echo the counters back —
            root._cpuPrevTotal = r.prevTotal      // unchanged when no cpu line
            if (r.diskUsedB !== undefined) root.diskUsedB = r.diskUsedB
            if (r.diskTotalB !== undefined) root.diskTotalB = r.diskTotalB
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
                var p = Info.parseNvidiaSmi(data)
                if (!p) return
                if (p.tempC !== undefined) root.gpuTempC = p.tempC
                if (p.usagePct !== undefined) root.gpuUsagePct = p.usagePct
                if (p.memUsedMiB !== undefined) root.gpuMemUsedMiB = p.memUsedMiB
                if (p.memTotalMiB !== undefined) root.gpuMemTotalMiB = p.memTotalMiB
                if (p.powerW !== undefined) root.gpuPowerW = p.powerW
                if (p.fanPct !== undefined) root.gpuFanPct = p.fanPct
                if (p.clockMHz !== undefined) root.gpuClockMHz = p.clockMHz
                if (p.seen) root._gpuSeen = true
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
            root.gpuProcesses = Info.parseGpuApps(out)
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
            var g = Info.parseGeo(out)   // null on offline / rate-limited / garbage
            if (g) {
                root.geoCity = g.city
                root.geoCountry = g.country
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
        var payload = Info.buildMetricsPayload({
            gpuSeen: root._gpuSeen,
            gpuUsagePct: root.gpuUsagePct,
            gpuMemUsedMiB: root.gpuMemUsedMiB,
            gpuMemTotalMiB: root.gpuMemTotalMiB,
            gpuTempC: root.gpuTempC,
            gpuPowerW: root.gpuPowerW,
            gpuFanPct: root.gpuFanPct,
            gpuClockMHz: root.gpuClockMHz,
            gpuProcesses: root.gpuProcesses,
            cpuPct: root.cpuPct,
            memUsedGiB: root.memUsedGiB,
            memTotalGiB: root.memTotalGiB,
            diskUsedB: root.diskUsedB,
            diskTotalB: root.diskTotalB
        }, Date.now())
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
