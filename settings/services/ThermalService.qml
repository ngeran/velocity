// =============================================================================
// ThermalService.qml — CPU / NVMe / coolant temperatures (hwmon)
// =============================================================================
//
// Reads sysfs hwmon:
//   • cpuTemp    — max over coretemp (Intel) / k10temp (AMD) temp*_input
//   • nvmeTemp   — max over hwmon name=="nvme" temp1_input
//   • coolantTemp — BEST-EFFORT: hwmon temp whose *_label matches water/coolant/
//                   liquid/aio. Most AIOs (incl. the MYSTIQUE, which is a vendor-
//                   specific USB device with no Linux driver) expose NO coolant
//                   sensor to userspace → coolantAvailable stays false and the UI
//                   shows "N/A". A configurable hwmon path can be wired in later.
//
// Process + SplitParser + Timer idiom mirrors SysInfoService.qml.
//
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io

Item {
    id: root

    property real cpuTemp: 0          // °C
    property real nvmeTemp: 0         // °C
    property real coolantTemp: 0      // °C
    property bool coolantAvailable: false

    function _parseMilli(buf) {
        var v = parseInt((buf || "").trim(), 10)
        return (!isNaN(v) && v > 0) ? +(v / 1000).toFixed(1) : 0
    }

    // ── CPU package temp: coretemp/k10temp, max sensor ──────────────────────
    Process {
        id: cpuTempProc
        command: ["sh", "-c",
            "for d in /sys/class/hwmon/hwmon*; do n=$(cat \"$d/name\" 2>/dev/null); " +
            "case \"$n\" in coretemp|k10temp) for i in $(seq 1 20); do " +
            "cat \"$d/temp${i}_input\" 2>/dev/null; done;; esac; done | sort -n | tail -1"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { cpuTempProc.buffer += data } }
        onRunningChanged: {
            if (!running && cpuTempProc.buffer.trim().length) {
                root.cpuTemp = root._parseMilli(cpuTempProc.buffer)
                cpuTempProc.buffer = ""
            }
        }
    }

    // ── NVMe temp: max over nvme hwmons ─────────────────────────────────────
    Process {
        id: nvmeProc
        command: ["sh", "-c",
            "for d in /sys/class/hwmon/hwmon*; do [ \"$(cat \"$d/name\" 2>/dev/null)\" = nvme ] " +
            "&& cat \"$d/temp1_input\" 2>/dev/null; done | sort -n | tail -1"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { nvmeProc.buffer += data } }
        onRunningChanged: {
            if (!running && nvmeProc.buffer.trim().length) {
                root.nvmeTemp = root._parseMilli(nvmeProc.buffer)
                nvmeProc.buffer = ""
            }
        }
    }

    // ── Coolant temp: best-effort label scan (usually unavailable) ──────────
    Process {
        id: coolantProc
        command: ["sh", "-c",
            "for d in /sys/class/hwmon/hwmon*; do for i in 1 2 3 4 5 6; do " +
            "l=$(cat \"$d/temp${i}_label\" 2>/dev/null); case \"$l\" in " +
            "*water*|*coolant*|*liquid*|*aio*) cat \"$d/temp${i}_input\" 2>/dev/null;; esac; done; done | sort -n | tail -1"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { coolantProc.buffer += data } }
        onRunningChanged: {
            var raw = (coolantProc.buffer || "").trim()
            if (!running && raw.length) {
                var v = parseInt(raw, 10)
                if (!isNaN(v) && v > 0) {
                    root.coolantTemp = +(v / 1000).toFixed(1)
                    root.coolantAvailable = true
                }
                coolantProc.buffer = ""
            }
        }
    }

    function refresh() {
        cpuTempProc.running = true
        nvmeProc.running = true
        coolantProc.running = true
    }

    // Temps move slowly; 5s is enough and keeps the hwmon scan cheap.
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
