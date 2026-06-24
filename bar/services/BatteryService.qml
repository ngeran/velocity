// =============================================================================
// BatteryService.qml — battery / AC power state monitoring
// =============================================================================
//
// One-shot probe walks /sys/class/power_supply/*. A system battery is any
// device named BAT* of type Battery; a Mains device reports AC online state.
//
// A machine with NO system battery is treated as on AC (it must be plugged in
// to run), so desktops report hasBattery=false, onAc=true.
//
// PROPERTIES
//   hasBattery : bool   — a system battery (BAT*) is present
//   onAc       : bool   — running on AC / wall power
//   percentage : int    — battery charge (0-100; 100 when no battery)
//   charging   : bool   — battery is charging
//   glyph      : string — Nerd Font glyph (battery level / charging / plug)
//   stateLabel : string — human status (CHARGING / ON BATTERY / AC POWER …)
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false

    property bool hasBattery: false
    property bool onAc: true
    property int percentage: 100
    property bool charging: false

    readonly property string glyph: {
        if (!root.hasBattery) return "󰇄"        // power plug (AC)
        if (root.charging) return "󰂄"
        if (root.percentage >= 95) return "󰁹"
        if (root.percentage < 10) return "󰁺"
        if (root.percentage < 30) return "󰁻"
        if (root.percentage < 50) return "󰁼"
        if (root.percentage < 70) return "󰁽"
        if (root.percentage < 85) return "󰁿"
        return "󰂀"
    }

    readonly property string stateLabel: {
        if (!root.hasBattery) return root.onAc ? "AC POWER" : "NO BATTERY"
        if (root.charging) return "CHARGING"
        if (root.percentage >= 95) return "FULLY CHARGED"
        return "ON BATTERY"
    }

    Process {
        id: probe
        command: ["sh", "-c", "for d in /sys/class/power_supply/*/; do n=$(basename \"$d\"); t=$(cat \"$d/type\" 2>/dev/null); if [ \"$t\" = \"Battery\" ]; then case \"$n\" in BAT*) echo \"BAT|$(cat \"$d/capacity\" 2>/dev/null)|$(cat \"$d/status\" 2>/dev/null)\";; esac; elif [ \"$t\" = \"Mains\" ]; then echo \"AC|$(cat \"$d/online\" 2>/dev/null)\"; fi; done"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { probe.buffer += data + "\n" } }
        onRunningChanged: {
            if (!running) {
                root._parse(probe.buffer)
                probe.buffer = ""
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!probe.running) probe.running = true }
    }

    function _parse(raw) {
        var lines = (raw || "").trim().split("\n")
        var bat = null
        var acOnline = false
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line.length === 0) continue
            var f = line.split("|")
            if (f[0] === "BAT") {
                bat = { capacity: parseInt(f[1]) || 0, status: (f[2] || "").toLowerCase() }
            } else if (f[0] === "AC") {
                if (f[1] === "1") acOnline = true
            }
        }
        root.hasBattery = !!bat
        root.onAc = acOnline || !root.hasBattery
        root.percentage = bat ? bat.capacity : 100
        root.charging = bat ? (bat.status === "charging") : false
    }
}
