// =============================================================================
// NetworkService.qml — Network connection state monitoring
// =============================================================================
//
// This singleton service monitors network connectivity status.
//
// PROPERTIES
//   isConnected: bool — True when connected to WiFi or Ethernet
//   connectionType: string — "wifi", "ethernet", or "" (disconnected)
//
// IMPLEMENTATION
//   - Polls `nmcli` every 3 seconds
//   - Parses TYPE:STATE format from nmcli output
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

    property string connectionType: ""
    property bool isConnected: false

    // =========================================================================
    // NETWORK POLLING
    // =========================================================================

    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE device | grep -E '^(wifi|ethernet):connected' | head -1"]
        property string buffer: ""
        stdout: SplitParser {
            onRead: function(data) { netProc.buffer += data }
        }
        onRunningChanged: {
            if (!running) {
                const line = netProc.buffer.trim()
                if (line.length > 0) {
                    const parts = line.split(":")
                    if (parts.length >= 2) {
                        root.connectionType = parts[0]
                        root.isConnected = true
                    } else {
                        root._reset()
                    }
                } else {
                    root._reset()
                }
                netProc.buffer = ""
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!netProc.running) netProc.running = true
        }
    }

    // =========================================================================
    // PRIVATE HELPERS
    // =========================================================================

    function _reset() {
        root.connectionType = ""
        root.isConnected = false
    }
}
