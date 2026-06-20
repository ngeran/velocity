// =============================================================================
// BatteryService.qml — Battery status monitoring
// =============================================================================
//
// This singleton service monitors laptop battery status.
//
// PROPERTIES
//   percentage: int — Battery charge level (0-100)
//   charging: bool — True when battery is charging
//   timeRemaining: string — Estimated time remaining (if available)
//
// IMPLEMENTATION
//   - Polls /sys/class/power_supply for battery info
//   - Updates every 30 seconds to avoid excessive reads
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false

    // =========================================================================
    // PUBLIC PROPERTIES
    // =========================================================================

    property int percentage: 100
    property bool charging: false
    property string timeRemaining: ""

    // =========================================================================
    // BATTERY POLLING
    // =========================================================================

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root._updateBattery()
    }

    Process {
        id: batProc
        command: ["cat", "/sys/class/power_supply/BAT0/capacity"]
        property string buffer: ""
        stdout: SplitParser {
            onRead: function(data) { batProc.buffer += data }
        }
        onRunningChanged: {
            if (!running && batProc.buffer.length > 0) {
                root.percentage = parseInt(batProc.buffer.trim()) || 0
                batProc.buffer = ""
            }
        }
    }

    Process {
        id: statusProc
        command: ["cat", "/sys/class/power_supply/BAT0/status"]
        property string buffer: ""
        stdout: SplitParser {
            onRead: function(data) { statusProc.buffer += data }
        }
        onRunningChanged: {
            if (!running && statusProc.buffer.length > 0) {
                const status = statusProc.buffer.trim()
                root.charging = status === "Charging"
                statusProc.buffer = ""
            }
        }
    }

    function _updateBattery() {
        batProc.running = true
        statusProc.running = true
    }
}
