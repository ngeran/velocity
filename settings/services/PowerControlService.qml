// =============================================================================
// PowerControlService.qml — battery / AC power state (sysfs)
// =============================================================================
//
// One-shot probe walks /sys/class/power_supply/* and pipes pipe-delimited
// fields per device. System battery = name starting with "BAT"; any other
// "Battery" type (e.g. hidpp_* peripherals) is surfaced as a peripheral.
//
// A machine with NO system battery is treated as on AC (it must be plugged in
// to run) — so desktops report onAc=true, state="ac".
//
// Exposes:
//   hasSystemBattery, onAc, percent, state, wattage, timeRemaining, peripherals
//   glyph      — Nerd Font glyph reflecting battery level / charging / plug
//   stateLabel — human status (CHARGING / ON BATTERY / CONNECTED TO OUTLET …)
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false

    property bool hasSystemBattery: false
    property bool onAc: true
    property int percent: 100
    property string state: "ac"   // charging | discharging | full | "not charging" | ac | unknown
    property real wattage: 0
    property string timeRemaining: "—"
    property var peripherals: []

    // derived presentation (data-only; color stays in the UI)
    readonly property string glyph: {
        if (!root.hasSystemBattery) return "󰇄"        // power plug (AC)
        if (root.state === "charging") return "󰂄"
        if (root.percent >= 95) return "󰁹"
        if (root.percent < 10) return "󰁺"
        if (root.percent < 30) return "󰁻"
        if (root.percent < 50) return "󰁼"
        if (root.percent < 70) return "󰁽"
        if (root.percent < 85) return "󰁿"
        return "󰂀"
    }
    readonly property string stateLabel: {
        if (!root.hasSystemBattery) return root.onAc ? "CONNECTED TO OUTLET" : "NO BATTERY"
        if (root.state === "charging") return "CHARGING"
        if (root.state === "discharging") return "ON BATTERY"
        if (root.state === "full") return "FULLY CHARGED"
        if (root.state === "not charging") return "NOT CHARGING"
        return root.state.toUpperCase()
    }

    Process {
        id: powerProbe
        command: ["sh", "-c", "for d in /sys/class/power_supply/*/; do n=$(basename \"$d\"); echo \"$n|$(cat \"$d/type\" 2>/dev/null)|$(cat \"$d/capacity\" 2>/dev/null)|$(cat \"$d/status\" 2>/dev/null)|$(cat \"$d/online\" 2>/dev/null)|$(cat \"$d/power_now\" 2>/dev/null)|$(cat \"$d/energy_now\" 2>/dev/null)\"; done"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { powerProbe.buffer += data + "\n" } }
        onRunningChanged: {
            if (!running) {
                var p = root._parsePower(powerProbe.buffer)
                root.hasSystemBattery = p.hasSystemBattery
                root.onAc = p.onAc
                root.percent = p.percent
                root.state = p.state
                root.wattage = p.wattage
                root.timeRemaining = p.timeRemaining
                root.peripherals = p.peripherals
                powerProbe.buffer = ""
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!powerProbe.running) powerProbe.running = true }
    }

    function _parsePower(raw) {
        var lines = (raw || "").trim().split("\n")
        var sys = null
        var acOnline = false
        var peripherals = []
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line.length === 0) continue
            var f = line.split("|")
            if (f.length < 2) continue
            var name = f[0], type = f[1], cap = f[2], status = f[3], online = f[4], power = f[5], enNow = f[6]
            if (type === "Mains") {
                if (online === "1") acOnline = true
            } else if (type === "Battery") {
                var entry = {
                    name: name,
                    capacity: parseInt(cap) || 0,
                    status: (status || "").toLowerCase(),
                    power: parseInt(power) || 0,
                    energyNow: parseInt(enNow) || 0
                }
                if (/^BAT/i.test(name)) sys = entry
                else peripherals.push(entry)
            }
        }

        var hasSys = !!sys
        var onAc = acOnline || !hasSys
        var percent = hasSys ? sys.capacity : 100
        var state = hasSys ? (sys.status || "unknown") : "ac"
        var wattage = (hasSys && sys.power > 0) ? sys.power / 1000000 : 0
        var timeRem = "—"
        if (hasSys && sys.power > 0 && sys.energyNow > 0 && wattage > 0) {
            var hours = (sys.energyNow / 1000000) / wattage
            var h = Math.floor(hours)
            var m = Math.round((hours - h) * 60)
            timeRem = (h > 0 ? h + "h " : "") + m + "m"
        }
        return {
            hasSystemBattery: hasSys, onAc: onAc, percent: percent, state: state,
            wattage: wattage, timeRemaining: timeRem, peripherals: peripherals
        }
    }
}
