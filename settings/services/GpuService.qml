// =============================================================================
// GpuService.qml — GPU telemetry, single vendor-aware module
// =============================================================================
//
// The ONE place the shell shells out for GPU data. All GPU consumers
// (CoreGpuSection, the CoreEngineService deepcool-LCD feed) bind to the
// properties below — they never call nvidia-smi themselves. (The bar's
// SystemInfoService keeps a separate legacy amdgpu reader.)
//
// VENDOR FLAG — `vendor` selects the backend. Only "nvidia" is implemented
// today (nvidia-smi). When the GPU changes (e.g. back to AMD), add an "amd"
// branch below using rocm-smi / sysfs (/sys/class/drm/card*/device/
// gpu_busy_percent + amdgpu gpu_metrics) and point `vendor` at it; the public
// property set above each branch stays identical, so CoreGpuSection and the
// LCD feed don't change. nvtop is a TUI (not scriptable) — the per-process
// list comes from nvidia-smi's --query-compute-apps, which exposes the same
// data nvtop shows.
//
// Process + SplitParser + Timer idiom mirrors SysInfoService.qml.
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io

Item {
    id: root

    // ── VENDOR SELECTOR ───────────────────────────────────────────────────
    // "nvidia" (nvidia-smi) today. Add "amd"/"intel" branches in refresh()
    // on a GPU swap — the public property set below stays the same shape.
    property string vendor: "nvidia"

    property string name: ""        // e.g. "NVIDIA GeForce RTX 5080"
    property real temp: 0           // °C
    property real util: 0           // %
    property real vramUsedGB: 0
    property real vramTotalGB: 0
    property real vramPct: 0
    property real powerW: 0
    property real fanPct: 0
    property real clockMHz: 0
    property bool present: false    // backend returned parseable data
    property var processes: []      // [{ pid, name, memMiB }] desc by mem, capped

    // ── NVIDIA backend — telemetry ────────────────────────────────────────
    // Fields: temp.gpu, util.gpu, mem.used, mem.total, power.draw, fan.speed,
    // clocks.gr, name. memory.* are MiB → /1024 for GB. power/fan can be [N/A]
    // → NaN → 0. name is a trailing string field (rejoined in case a GPU name
    // ever contained a comma).
    Process {
        id: gpuProc
        command: [
            "nvidia-smi",
            "--query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw,fan.speed,clocks.gr,name",
            "--format=csv,noheader,nounits"
        ]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { gpuProc.buffer += data } }
        onRunningChanged: {
            if (!running && gpuProc.buffer.length > 0) {
                var raw = gpuProc.buffer.trim().split("\n")[0].split(",")
                var f = []
                for (var i = 0; i < 7; i++) f.push(parseFloat((raw[i] || "").trim()))
                var nameStr = raw.length > 7 ? raw.slice(7).join(",").trim() : ""
                if (f.length >= 7 && !isNaN(f[0])) {
                    root.name = nameStr || root.name
                    root.temp = f[0]
                    root.util = isNaN(f[1]) ? 0 : f[1]
                    root.vramUsedGB = +(f[2] / 1024).toFixed(2)
                    root.vramTotalGB = +(f[3] / 1024).toFixed(2)
                    root.vramPct = root.vramTotalGB > 0
                        ? +(root.vramUsedGB / root.vramTotalGB * 100).toFixed(1) : 0
                    root.powerW = isNaN(f[4]) ? 0 : f[4]
                    root.fanPct = isNaN(f[5]) ? 0 : f[5]
                    root.clockMHz = isNaN(f[6]) ? 0 : f[6]
                    root.present = true
                }
                gpuProc.buffer = ""
            }
        }
    }

    // ── NVIDIA backend — per-process GPU consumers (nvtop-equivalent) ─────
    // Fields: pid, process_name, used_memory. process_name is an exe path →
    // basenamed. used_memory is the LAST field; the path sits between pid and
    // it (slice defensively handles any comma in the path). Sorted desc by
    // mem, capped to 6.
    Process {
        id: appsProc
        command: [
            "nvidia-smi",
            "--query-compute-apps=pid,process_name,used_memory",
            "--format=csv,noheader,nounits"
        ]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { appsProc.buffer += data } }
        onRunningChanged: {
            if (!running && appsProc.buffer.length > 0) {
                var lines = appsProc.buffer.trim().split("\n")
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
                root.processes = procs.slice(0, 6)
                appsProc.buffer = ""
            } else if (!running && appsProc.buffer.length === 0) {
                // nvidia-smi returns no rows when nothing is using the GPU.
                root.processes = []
            }
        }
    }

    // ── AMD / Intel backend (FUTURE) ──────────────────────────────────────
    // Not implemented. On a GPU swap, add the branch here (rocm-smi --json or
    // sysfs gpu_metrics) feeding the same root.* properties, and gate the two
    // Processes above on vendor === "nvidia" so only the active backend polls.
    // ----------------------------------------------------------------------

    function refresh() {
        if (root.vendor === "nvidia") {
            gpuProc.running = true
            appsProc.running = true
        }
        // else: future amd/intel branch
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
