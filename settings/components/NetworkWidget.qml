// =============================================================================
// components/NetworkWidget.qml
// Network Command Panel — Ring Gauge + SSID/IP Metadata
//
// USAGE:
//   UI.NetworkWidget {
//       anchors.fill: parent
//       anchors.margins: 40
//   }
//
// DATA PROBES:
//   Uses SplitParser API for process output (onStreamedLine not available)
//
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "." as UI

ColumnLayout {
    id: netRoot

    spacing: 0

    // -------------------------------------------------------------------------
    // INTERNAL PROBE STATE — updated by polling Processes
    // -------------------------------------------------------------------------
    property string _ssid:      "SCANNING..."
    property string _ipAddr:    "---"
    property string _iface:     "---"
    property real   _integrity: 0.0   // 0.0–1.0, drives the NetworkRing

    // -------------------------------------------------------------------------
    // HARDWARE PROBE: IP Address
    // `ip -4 route get 1` returns the default-route interface and src IP.
    // -------------------------------------------------------------------------
    Process {
        id: ipProbe
        command: ["ip", "-4", "route", "get", "1"]
        property string buffer: ""

        stdout: SplitParser {
            onRead: function(data) { ipProbe.buffer += data }
        }

        onRunningChanged: {
            if (!running) {
                const lines = ipProbe.buffer.trim().split("\n")
                for (let i = 0; i < lines.length; i++) {
                    let srcMatch = lines[i].match(/src\s+([\d.]+)/)
                    if (srcMatch) netRoot._ipAddr = srcMatch[1]

                    let devMatch = lines[i].match(/dev\s+(\S+)/)
                    if (devMatch) netRoot._iface = devMatch[1]
                }
                ipProbe.buffer = ""
            }
        }
    }

    // Re-poll every 5 seconds
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: ipProbe.running = true
    }

    // -------------------------------------------------------------------------
    // HARDWARE PROBE: SSID
    // `iwgetid -r` returns the raw SSID string of the current AP.
    // -------------------------------------------------------------------------
    Process {
        id: ssidProbe
        command: ["iwgetid", "-r"]
        property string buffer: ""

        stdout: SplitParser {
            onRead: function(data) { ssidProbe.buffer += data }
        }

        onRunningChanged: {
            if (!running) {
                let trimmed = ssidProbe.buffer.trim()
                if (trimmed.length > 0) netRoot._ssid = trimmed
                else netRoot._ssid = "NO WIRELESS"
                ssidProbe.buffer = ""
            }
        }
    }

    Timer {
        interval: 10000; running: true; repeat: true
        onTriggered: ssidProbe.running = true
    }

    // -------------------------------------------------------------------------
    // SECTION HEADER ROW
    // -------------------------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true

        Text {
            text:           "NETWORK COMMAND"
            color:          UI.Colors.textMuted
            font.pixelSize: 10
            font.bold:      true
            font.family:    "monospace"
            font.letterSpacing: 1.5
        }

        Item { Layout.fillWidth: true }

        // Live status badge
        Text {
            text:           netRoot._integrity >= 0.5 ? "ACTIVE" : "DEGRADED"
            color:          netRoot._integrity >= 0.5 ? UI.Colors.accentCyan : UI.Colors.accentWarn
            font.pixelSize: 10
            font.family:    "monospace"
            font.letterSpacing: 1.2
        }
    }

    // -------------------------------------------------------------------------
    // RING + METADATA ROW
    // -------------------------------------------------------------------------
    RowLayout {
        spacing:             24
        Layout.topMargin:    20
        Layout.fillWidth:    true

        // Ring gauge — drives from _integrity property
        UI.NetworkRing {
            id: liveRing
            width:          160
            height:         160
            integrityValue: netRoot._integrity
            label:          "SIGNAL"
        }

        // ---- Metadata column ------------------------------------------------
        ColumnLayout {
            spacing: 16
            Layout.fillWidth: true

            // SSID
            ColumnLayout {
                spacing: 4
                Text {
                    text:           "SSID"
                    color:          UI.Colors.textMuted
                    font.pixelSize: 8
                    font.family:    "monospace"
                    font.letterSpacing: 1.5
                }
                Text {
                    text:           netRoot._ssid
                    color:          UI.Colors.primary
                    font.bold:      true
                    font.family:    "monospace"
                    elide:          Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // IP Address
            ColumnLayout {
                spacing: 4
                Text {
                    text:           "IP ADDRESS"
                    color:          UI.Colors.textMuted
                    font.pixelSize: 8
                    font.family:    "monospace"
                    font.letterSpacing: 1.5
                }
                Text {
                    text:           netRoot._ipAddr
                    color:          UI.Colors.accentCyan
                    font.family:    "monospace"
                }
            }

            // Interface
            ColumnLayout {
                spacing: 4
                Text {
                    text:           "INTERFACE"
                    color:          UI.Colors.textMuted
                    font.pixelSize: 8
                    font.family:    "monospace"
                    font.letterSpacing: 1.5
                }
                Text {
                    text:           netRoot._iface
                    color:          UI.Colors.textVariant
                    font.family:    "monospace"
                }
            }
        }
    }

    // Absorb remaining vertical space
    Item { Layout.fillHeight: true }
}
