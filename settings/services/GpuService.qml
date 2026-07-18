// =============================================================================
// GpuService.qml — NVIDIA GPU telemetry (nvidia-smi)
// =============================================================================
//
// Single source of NVIDIA GPU data for the Core Engine tab + the deepcool-py
// sink feed. Polls nvidia-smi every 2s (cold-start ~30ms is fine at this cadence;
// deepcool-py previously spawned its own nvidia-smi at 1Hz — now it just reads
// metrics.json, so this is the one place that shells out). AMD/Intel GPUs report
// 0 here (the legacy amdgpu reader still lives in SysInfoService for the bar).
//
// Process + SplitParser + Timer idiom mirrors SysInfoService.qml.
//
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io

Item {
    id: root

    property real temp: 0          // °C
    property real util: 0          // %
    property real vramUsedGB: 0
    property real vramTotalGB: 0
    property real vramPct: 0
    property real powerW: 0
    property real fanPct: 0
    property real clockMHz: 0
    property bool present: false   // nvidia-smi returned parseable data

    // ── nvidia-smi query (first GPU only) ───────────────────────────────────
    // Fields: temp.gpu, util.gpu, mem.used, mem.total, power.draw, fan.speed, clocks.gr
    // memory.* are MiB → /1024 for GB. power/fan can be [N/A] → NaN → 0.
    Process {
        id: gpuProc
        command: [
            "nvidia-smi",
            "--query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw,fan.speed,clocks.gr",
            "--format=csv,noheader,nounits"
        ]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { gpuProc.buffer += data } }
        onRunningChanged: {
            if (!running && gpuProc.buffer.length > 0) {
                var line = gpuProc.buffer.trim().split("\n")[0]
                var raw = line.split(",")
                var f = []
                for (var i = 0; i < raw.length; i++)
                    f.push(parseFloat(raw[i].trim()))
                if (f.length >= 7 && !isNaN(f[0])) {
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

    function refresh() { gpuProc.running = true }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
