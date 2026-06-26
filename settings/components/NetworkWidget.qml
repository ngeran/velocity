// =============================================================================
// NetworkWidget.qml — Full-bleed network status card for bento dashboard
// VERSION: V2.0 — Item root, fills card, stacked metadata layout
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../config" as Config
import "." as Components

Item {
    id: netRoot

    property string _ssid:      "SCANNING..."
    property string _ipAddr:    "---"
    property string _iface:     "---"
    property real   _integrity: 0.0

    // ── PROBES ────────────────────────────────────────────────────────────────
    Process {
        id: ipProbe
        command: ["ip", "-4", "route", "get", "1"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { ipProbe.buffer += data } }
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
    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: ipProbe.running = true }

    Process {
        id: ssidProbe
        command: ["iwgetid", "-r"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { ssidProbe.buffer += data } }
        onRunningChanged: {
            if (!running) {
                let t = ssidProbe.buffer.trim()
                netRoot._ssid = t.length > 0 ? t : "NO WIRELESS"
                ssidProbe.buffer = ""
            }
        }
    }
    Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: ssidProbe.running = true }

    // ── LAYOUT ────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header + status badge
        Item {
            Layout.fillWidth: true
            Layout.bottomMargin: 14
            height: 18

            Components.WidgetHeader {
                icon: "󰖩"
                label: "NETWORK"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 18
                width: statusLabel.implicitWidth + 16
                color: netRoot._integrity >= 0.5 ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.12) : Config.ThemeConfig.tint(Config.ThemeConfig.colors.error, 0.12)
                border.width: 1
                border.color: netRoot._integrity >= 0.5 ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.error

                Text {
                    id: statusLabel
                    anchors.centerIn: parent
                    text: netRoot._integrity >= 0.5 ? "ACTIVE" : "DEGRADED"
                    color: netRoot._integrity >= 0.5 ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.error
                    font.pixelSize: 8; font.bold: true
                    font.family: Config.SettingsConfig.fontFamily
                    font.letterSpacing: 1.5
                }
            }
        }

        // ── RING + METADATA ───────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            // Ring gauge
            Components.NetworkRing {
                id: liveRing
                width: 110
                height: 110
                integrityValue: netRoot._integrity
                label: "SIGNAL"
                Layout.alignment: Qt.AlignVCenter
            }

            // Metadata stack
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Repeater {
                    model: [
                        { label: "SSID",      value: netRoot._ssid,   color: Config.ThemeConfig.colors.primary  },
                        { label: "IP",        value: netRoot._ipAddr, color: Config.ThemeConfig.colors.secondary                         },
                        { label: "INTERFACE", value: netRoot._iface,  color: Config.ThemeConfig.colors.primary  }
                    ]

                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2

                        Text {
                            text: modelData.label
                            color: Config.ThemeConfig.colors.textDim
                            font.pixelSize: 8
                            font.family: Config.SettingsConfig.fontFamily
                            font.letterSpacing: 1.5
                        }

                        Text {
                            text: modelData.value
                            color: modelData.color
                            font.pixelSize: 11
                            font.bold: true
                            font.family: Config.SettingsConfig.fontFamily
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        // Divider between rows (not after last)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Config.ThemeConfig.colors.outlineVariant
                            opacity: 0.5
                            visible: index < 2
                            Layout.topMargin: 6
                            Layout.bottomMargin: 6
                        }
                    }
                }
            }
        }
    }
}
