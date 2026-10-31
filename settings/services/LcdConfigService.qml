// =============================================================================
// LcdConfigService.qml — the ONE owner of deepcool-config.json
// =============================================================================
// The Mystique AIO LCD control surface now lives in TWO views at once (the
// embedded panel in the Core telemetry pane + the standalone MYSTIQUE AIO
// pane; both are visibility-gated Items, not Loaders). State therefore lives
// HERE, never in a panel copy — every UI pick goes through a setter, which
// persists and notifies both instances.
//
// File contract (external deepcool-py --sink reads it LIVE — shape is frozen):
//   { enabled, mode, rotation, unit,
//     slots: { cpu_temp, gpu_temp, usage, ram, freq },
//     sources: { coolant: true, nvme: true } }
// Written through ThemeService._atomicWrite (tmp+mv) so the daemon never sees
// a half-written file.
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
import Quickshell.Io

QtObject {
    id: root

    // --- state (loaded from disk at boot; setters persist) ---
    property bool lcdEnabled: true
    property string mode: "cpu"             // cpu | gpu | gpu_focus
    property int rotation: 0                // 0 | 90 | 180 | 270
    property string unit: "C"               // C | F
    property string mainTempSource: "cpu_temp"
    property string gpuTempSource: "gpu_temp"
    property string usageSource: "cpu_usage"
    property string ramSource: "ram_pct"
    property string freqSource: "cpu_ghz"
    property bool loaded: false

    readonly property string cfgPath: StandardPaths.writableLocation(StandardPaths.ConfigLocation)
                                      .toString().replace("file://", "") + "/quickshell/deepcool-config.json"

    // --- setters (the ONLY write path — both panels stay in sync) ---
    function setEnabled(b) { root.lcdEnabled = b; root.save() }
    function setMode(m) { root.mode = m; root.save() }
    function setRotation(r) { root.rotation = r; root.save() }
    function setUnit(u) { root.unit = u; root.save() }
    function setMainTempSource(k) { root.mainTempSource = k; root.save() }
    function setGpuTempSource(k) { root.gpuTempSource = k; root.save() }
    function setUsageSource(k) { root.usageSource = k; root.save() }
    function setRamSource(k) { root.ramSource = k; root.save() }

    // --- formatting helpers (moved verbatim from the old CoreLcdPane) ---
    function tempStr(celsius) {
        var v = root.unit === "F" ? celsius * 9.0 / 5.0 + 32.0 : celsius
        return Math.round(v) + "°"
    }
    function metricValue(key) {
        var m = HostBridge.metrics
        if (!m) return "—"
        switch (key) {
            case "cpu_temp": return tempStr(m.cpuTemp)
            case "gpu_temp": return tempStr(m.temp)
            case "coolant_temp": return m.coolantAvailable ? tempStr(m.coolantTemp) : "N/A"
            case "nvme_temp": return m.nvmeTemp > 0 ? tempStr(m.nvmeTemp) : "N/A"
            case "cpu_usage": return Math.round(m.cpuUsage) + "%"
            case "gpu_usage": return Math.round(m.util) + "%"
            case "ram_pct": return Math.round(m.ramPct) + "%"
            case "swap_pct": return Math.round(m.swapPct) + "%"
            case "disk_pct": return Math.round(m.diskPct) + "%"
            case "cpu_ghz": return m.cpuGhz.toFixed(2)
        }
        return "—"
    }

    // --- persistence ---
    function save() {
        var cfg = { enabled: root.lcdEnabled, mode: root.mode, rotation: root.rotation, unit: root.unit,
            slots: { cpu_temp: root.mainTempSource, gpu_temp: root.gpuTempSource, usage: root.usageSource, ram: root.ramSource, freq: root.freqSource },
            sources: { coolant: true, nvme: true } }
        var json = JSON.stringify(cfg, null, 2)
        // Shared atomic funnel (tmp + mv): readers (deepcool-py --sink) never
        // see a half-written file.
        ThemeService._atomicWrite(root.cfgPath, json)
    }

    property Process loadProc: Process {
        command: []; running: false
        property string buffer: ""
        stdout: SplitParser { onRead: function(d) { loadProc.buffer += d + "\n" } }
        onRunningChanged: {
            if (!running && loadProc.buffer.length) {
                try {
                    var d = JSON.parse(loadProc.buffer)
                    root.lcdEnabled = (d.enabled !== false)
                    root.mode = d.mode || "cpu"; root.rotation = d.rotation || 0; root.unit = d.unit || "C"
                    var s = d.slots || {}
                    root.mainTempSource = s.cpu_temp || "cpu_temp"; root.gpuTempSource = s.gpu_temp || "gpu_temp"
                    root.usageSource = s.usage || "cpu_usage"; root.ramSource = s.ram || "ram_pct"; root.freqSource = s.freq || "cpu_ghz"
                    root.loaded = true
                } catch (e) {}
                loadProc.buffer = ""
            }
        }
    }
    Component.onCompleted: { loadProc.command = ["cat", root.cfgPath]; loadProc.running = true }
}
