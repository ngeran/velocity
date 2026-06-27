// =============================================================================
// NetworkWidget.qml — High-Reliability Bento Network Card
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../config" as Config
import "." as Components

Item {
    id: netRoot

    // ── DATA PROPERTIES ──────────────────────────────────────────────────────
    property string _ssid:      "SCANNING"
    property string _ipAddr:    "0.0.0.0"
    property real   _signal:    0.0
    property bool   _isConnected: false

    // ── LOGIC: PROBES ────────────────────────────────────────────────────────

    // 1. IP Probe (Confirmed Working)
    Process {
        id: ipProbe
        command: ["sh", "-c", "ip route get 1.1.1.1 | grep -Po 'src \\K[\\d.]+'"]
        stdout: SplitParser { onRead: function(data) { 
            let t = data.trim();
            if (t.length > 0) netRoot._ipAddr = t;
        }}
    }

    // 2. Intelligent Network Probe
    // Step A: Determine active SSID & Connection Type
    // Step B: Get signal strength
    Process {
        id: netProbe
        command: ["sh", "-c", "nmcli -t -f TYPE,DEVICE,CONNECTION,STATE dev | grep ':connected' | head -1"]
        stdout: SplitParser { onRead: function(data) {
            let parts = data.trim().split(':'); 
            // parts format: TYPE:DEVICE:CONNECTION:STATE
            if (parts.length >= 3) {
                let type = parts[0];
                let connName = parts[2];
                netRoot._isConnected = true;

                if (type === "802-11-wireless" || type === "wifi") {
                    netRoot._ssid = connName;
                    // Trigger a quick signal check for this specific SSID
                    signalProbe.running = true;
                } else {
                    netRoot._ssid = "WIRED CONNECTION";
                    netRoot._signal = 1.0;
                }
            } else {
                netRoot._isConnected = false;
                netRoot._ssid = "OFFLINE";
                netRoot._signal = 0;
            }
        }}
    }

    // 3. Specific Signal Probe
    Process {
        id: signalProbe
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SIGNAL dev wifi | grep '^yes:' | cut -d: -f2"]
        stdout: SplitParser { onRead: function(data) {
            let s = parseInt(data.trim());
            if (!isNaN(s)) netRoot._signal = s / 100.0;
        }}
    }

    Timer { 
        interval: 5000; running: true; repeat: true; triggeredOnStart: true; 
        onTriggered: { ipProbe.running = true; netProbe.running = true; } 
    }

    // ── VIEW: LAYOUT ─────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 0

        // --- SECTION: Header (Label + Status) ---
        Item {
            Layout.fillWidth: true
            Layout.bottomMargin: 10
            height: 20

            Components.WidgetHeader {
                icon: "󰖩"
                label: "NETWORK"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }

            // ONLINE/CONNECTED Status + Breathing Dot (10px left from right edge)
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10 
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    text: netRoot._isConnected ? "CONNECTED" : "OFFLINE"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                    color: netRoot._isConnected ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.error
                }

                // Breathing Dot
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: netRoot._isConnected ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.error
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Rectangle {
                        anchors.fill: parent; radius: 4; color: parent.color; opacity: 0.3
                        scale: pulseAnim.scaleVal
                        SequentialAnimation on scale {
                            id: pulseAnim; property real scaleVal: 1.0
                            running: netRoot._isConnected; loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 3.0; duration: 1500; easing.type: Easing.OutExpo }
                            NumberAnimation { from: 3.0; to: 1.0; duration: 0 }
                        }
                    }
                }
            }
        }

        // --- SECTION: Content ---
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 15

            // Left: Signal Ring
            Item {
                Layout.preferredWidth: 110; Layout.preferredHeight: 110
                Layout.alignment: Qt.AlignVCenter

                Components.NetworkRing {
                    anchors.fill: parent
                    integrityValue: netRoot._signal
                    label: Math.round(netRoot._signal * 100) + "%"
                }
                
                Text {
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 22; anchors.horizontalCenter: parent.horizontalCenter
                    text: "STRENGTH"; font.pixelSize: 7; font.weight: Font.Bold
                    color: Config.ThemeConfig.colors.textDim; opacity: 0.5; font.letterSpacing: 1
                }
            }

            // Right: Metadata Stack
            ColumnLayout {
                Layout.fillWidth: true; spacing: 12; Layout.alignment: Qt.AlignVCenter

                Column {
                    spacing: 0
                    Text { text: "ACCESS POINT"; font.pixelSize: 8; font.weight: Font.Bold; color: Config.ThemeConfig.colors.textDim; font.letterSpacing: 1.5 }
                    Text { 
                        text: netRoot._ssid.toUpperCase()
                        font.pixelSize: 15; font.weight: Font.Black
                        color: Config.ThemeConfig.colors.primary; elide: Text.ElideRight; Layout.fillWidth: true
                    }
                }

                Column {
                    spacing: 0
                    Text { text: "IPV4 ADDRESS"; font.pixelSize: 8; font.weight: Font.Bold; color: Config.ThemeConfig.colors.textDim; font.letterSpacing: 1.5 }
                    Text { 
                        text: netRoot._ipAddr
                        font.pixelSize: 12; font.weight: Font.Medium; font.family: "Monospace"
                        color: Config.ThemeConfig.colors.secondary
                    }
                }
            }
        }
    }
}
