// =============================================================================
// BluetoothService.qml — Bluetooth state monitoring
// =============================================================================
//
// This singleton service monitors Bluetooth adapter and device state.
//
// PROPERTIES
//   powered: bool — True when Bluetooth adapter is powered on
//   deviceCount: int — Number of connected Bluetooth devices
//
// METHODS
//   togglePower() — Toggle Bluetooth adapter power state
//
// IMPLEMENTATION
//   - Polls `bluetoothctl show` for power state every 6s
//   - Polls `bluetoothctl devices Connected` for device count
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

    property bool powered: false
    property int deviceCount: 0

    // =========================================================================
    // BLUETOOTH POLLING
    // =========================================================================

    Process {
        id: btShowProc
        command: ["bluetoothctl", "show"]
        property string buffer: ""
        stdout: SplitParser {
            onRead: function(data) { btShowProc.buffer += data }
        }
        onRunningChanged: {
            if (!running) {
                root.powered = btShowProc.buffer.indexOf("Powered: yes") !== -1
                btShowProc.buffer = ""
            }
        }
    }

    Process {
        id: btDevProc
        command: ["bluetoothctl", "devices", "Connected"]
        property string buffer: ""
        stdout: SplitParser {
            onRead: function(data) { btDevProc.buffer += data }
        }
        onRunningChanged: {
            if (!running) {
                const lines = btDevProc.buffer.trim().split("\n").filter(l => l.startsWith("Device"))
                root.deviceCount = lines.length
                btDevProc.buffer = ""
            }
        }
    }

    Timer {
        interval: 6000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!btShowProc.running) btShowProc.running = true
            if (!btDevProc.running) btDevProc.running = true
        }
    }

    // =========================================================================
    // POWER TOGGLE
    // =========================================================================

    Process {
        id: toggleProc
        command: ["bluetoothctl", "power", "toggle"]
    }

    function togglePower() {
        toggleProc.running = true
    }
}
