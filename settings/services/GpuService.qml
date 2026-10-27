// =============================================================================
// GpuService.qml — GPU telemetry, file-fed (H7)
// =============================================================================
//
// The GPU consumers (CoreGpuSection, the SystemMetricsService deepcool-LCD feed)
// bind to the properties below. Since H7 the bar's SystemInfoService is the
// ONE repo-side GPU prober: it publishes
// $XDG_RUNTIME_DIR/velocity/metrics.json (atomic tmp+mv, lease-gated) and this
// service READS it — no GPU fork in this process anymore. The 2s
// reload Timer below (lease-gated by SystemMetricsService) is the reader, not a
// poll of the GPU.
//
// watchChanges stays FALSE: the bar writes via tmp+mv, and FileView's watch
// does not fire on renames (KernelEventReader lesson) — the timer reload is the
// delivery mechanism.
//
// VENDOR FLAG — `vendor` names the expected backend shape. Only "nvidia"
// fields are published today. On a GPU swap, the BAR's prober grows the new
// branch (rocm-smi / sysfs) and keeps publishing this same file schema; the
// properties below stay identical, so CoreGpuSection and the LCD feed don't
// change.
//
// The static GPU NAME still comes from the bar's fastfetch profile (overlay
// opens) — this file carries live fields only.
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../config" as Config
import "History.js" as History

Item {
    id: root

    property string vendor: "nvidia"

    property string name: ""        // static — bar's fastfetch profile (may stay "")
    property real temp: 0           // °C
    property real util: 0           // %
    property real vramUsedGB: 0
    property real vramTotalGB: 0
    property real vramPct: 0
    property real powerW: 0
    property real fanPct: 0
    property real clockMHz: 0
    property bool present: false    // file carried a gpu object
    property var processes: []      // [{ pid, name, memMiB }] desc by mem, capped

    // ── 2-min rolling utilisation history ({time,value}) for the Core chart —
    // singleton-owned so it survives the dashboard Loader teardown on close.
    property var gpuHistory: []

    readonly property string metricsPath:
        (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/" + (Quickshell.env("UID") || "1000"))
        + "/velocity/metrics.json"

    FileView {
        id: metricsFile
        path: root.metricsPath
        watchChanges: false          // tmp+mv renames don't fire it — Timer reloads
        printErrors: false
        onTextChanged: root._ingest(text())
    }

    function _ingest(raw) {
        var v = null
        try { v = JSON.parse(raw) } catch (e) { v = null }
        var g = v && typeof v === "object" ? v.gpu : null
        if (!g || typeof g !== "object") { root.present = false; return }
        root.present = true
        root.temp = typeof g.tempC === "number" ? g.tempC : 0
        root.util = typeof g.pct === "number" ? g.pct : 0
        root.vramUsedGB = +(g.memUsedB / 1073741824).toFixed(2)
        root.vramTotalGB = +(g.memTotalB / 1073741824).toFixed(2)
        root.vramPct = root.vramTotalGB > 0
            ? +(root.vramUsedGB / root.vramTotalGB * 100).toFixed(1) : 0
        root.powerW = typeof g.powerW === "number" ? g.powerW : 0
        root.fanPct = typeof g.fanPct === "number" ? g.fanPct : 0
        root.clockMHz = typeof g.clockMHz === "number" ? g.clockMHz : 0
        root.processes = Array.isArray(g.processes) ? g.processes : []
        // Chart samples only while a consumer actually watches (idle-file
        // rewrites must not churn properties with the dashboard closed).
        if (SystemMetricsService.telemetryWanted)
            root.gpuHistory = History.appendHistory(root.gpuHistory, Date.now(), root.util,
                                                     120000, 130)
    }

    function refresh() {
        metricsFile.reload()         // ASYNC — parse lands in onTextChanged
    }

    // Reader cadence: 2s while a consumer wants telemetry (Core tab open or
    // the deepcool LCD daemon alive — SystemMetricsService owns the gate). The
    // BAR's poll underneath is lease-gated; SystemMetricsService renews it.
    Timer {
        interval: 2000
        running: SystemMetricsService.telemetryWanted
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
