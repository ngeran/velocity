// =============================================================================
// NetworkWidget.qml — High-Reliability Bento Network Card (Matrix layout)
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../config" as Config
import "." as Components

Item {
    id: netRoot

    // ── DATA PROPERTIES ──────────────────────────────────────────────────────
    property string _ssid:        "SCANNING"
    property string _ipAddr:      "0.0.0.0"
    property string _publicIp:    "—"
    property string _device:      ""
    property real   _signal:      0.0
    property bool   _isConnected: false
    property real   _inbound:     0.0   // Mb/s
    property real   _outbound:    0.0   // Mb/s

    // Traffic rate state
    property real _prevRx:   0
    property real _prevTx:   0
    property real _prevTime: 0

    // ── LOGIC: PROBES ────────────────────────────────────────────────────────

    // 1. IP Probe (internal)
    Process {
        id: ipProbe
        command: ["sh", "-c", "ip route get 1.1.1.1 2>/dev/null | grep -Po 'src \\K[\\d.]+' || echo ''"]
        stdout: SplitParser {
            onRead: function(data) {
                let t = data.trim();
                if (t.length > 0) netRoot._ipAddr = t;
            }
        }
    }

    // 2. Intelligent Network Probe (type, device, connection, state)
    Process {
        id: netProbe
        command: ["sh", "-c", "nmcli -t -f TYPE,DEVICE,CONNECTION,STATE dev 2>/dev/null | grep ':connected' | head -1"]
        stdout: SplitParser {
            onRead: function(data) {
                let parts = data.trim().split(':');
                // parts: TYPE:DEVICE:CONNECTION:STATE
                if (parts.length >= 3) {
                    let type     = parts[0];
                    let device   = parts[1];
                    let connName = parts[2];
                    netRoot._isConnected = true;
                    netRoot._device = device;

                    if (type === "802-11-wireless" || type === "wifi") {
                        netRoot._ssid = connName;
                        signalProbe.running = true;
                    } else {
                        netRoot._ssid = "WIRED CONNECTION";
                        netRoot._signal = 1.0;
                    }
                } else {
                    netRoot._isConnected = false;
                    netRoot._ssid = "OFFLINE";
                    netRoot._signal = 0;
                    netRoot._device = "";
                }
            }
        }
    }

    // 3. Specific Signal Probe
    Process {
        id: signalProbe
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SIGNAL dev wifi 2>/dev/null | grep '^yes:' | cut -d: -f2"]
        stdout: SplitParser {
            onRead: function(data) {
                let s = parseInt(data.trim());
                if (!isNaN(s)) netRoot._signal = s / 100.0;
            }
        }
    }

    // 4. Public IP Probe (infrequent)
    Process {
        id: publicIpProbe
        command: ["sh", "-c", "curl -s --max-time 3 ifconfig.me 2>/dev/null || curl -s --max-time 3 icanhazip.com 2>/dev/null || echo '—'"]
        stdout: SplitParser {
            onRead: function(data) {
                let t = data.trim();
                if (t.length > 0 && t.indexOf('.') !== -1) netRoot._publicIp = t;
            }
        }
    }

    // 5. Traffic stats probe
    Process {
        id: trafficProbe
        command: {
            if (netRoot._device.length > 0)
                return ["sh", "-c", "cat /sys/class/net/" + netRoot._device + "/statistics/rx_bytes /sys/class/net/" + netRoot._device + "/statistics/tx_bytes 2>/dev/null || echo '0 0'"];
            return ["sh", "-c", "echo '0 0'"];
        }
        stdout: SplitParser {
            onRead: function(data) {
                let lines = data.trim().split(/\s+/);
                if (lines.length < 2) return;
                let rx = parseFloat(lines[0]);
                let tx = parseFloat(lines[1]);
                if (isNaN(rx) || isNaN(tx)) return;

                let now = Date.now() / 1000.0;
                if (netRoot._prevTime > 0 && now > netRoot._prevTime) {
                    let dt = now - netRoot._prevTime;
                    // bytes → bits → Mb/s
                    netRoot._inbound  = Math.max(0, (rx - netRoot._prevRx) * 8 / 1e6 / dt);
                    netRoot._outbound = Math.max(0, (tx - netRoot._prevTx) * 8 / 1e6 / dt);
                }
                netRoot._prevRx   = rx;
                netRoot._prevTx   = tx;
                netRoot._prevTime = now;
            }
        }
    }

    // Main refresh timer (connection + IP + traffic)
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            ipProbe.running = true;
            netProbe.running = true;
            if (netRoot._device.length > 0)
                trafficProbe.running = true;
        }
    }

    // Public IP less frequent
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: publicIpProbe.running = true
    }

    // ── VIEW: LAYOUT ─────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // --- HEADER: NETWORK_MATRIX + TRAFFIC ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Icon + Title
            Row {
                spacing: 8
                Layout.alignment: Qt.AlignVCenter

                // Network matrix style icon
                Text {
                    text: "󰒍"
                    font.pixelSize: 18
                    color: Config.ThemeConfig.colors.secondary || "#00dce5"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "NETWORK_MATRIX"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                    color: Config.ThemeConfig.colors.text || "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item { Layout.fillWidth: true }

            // Traffic inbound / outbound
            Row {
                spacing: 18
                Layout.alignment: Qt.AlignVCenter

                Column {
                    spacing: 1
                    Text {
                        text: "TRAFFIC_INBOUND"
                        font.pixelSize: 8
                        font.weight: Font.Bold
                        font.letterSpacing: 1.0
                        color: Config.ThemeConfig.colors.textDim || "#808080"
                    }
                    Text {
                        text: netRoot._inbound.toFixed(1) + " Mb/s"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: Config.ThemeConfig.colors.warning || "#fbbf24"
                    }
                }

                Column {
                    spacing: 1
                    Text {
                        text: "TRAFFIC_OUTBOUND"
                        font.pixelSize: 8
                        font.weight: Font.Bold
                        font.letterSpacing: 1.0
                        color: Config.ThemeConfig.colors.textDim || "#808080"
                    }
                    Text {
                        text: netRoot._outbound.toFixed(1) + " Mb/s"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: Config.ThemeConfig.colors.secondary || "#00dce5"
                    }
                }
            }
        }

        // --- CONTENT: Ring + Info stack ---
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            // Left: Signal Ring
            Item {
                Layout.preferredWidth: 130
                Layout.preferredHeight: 130
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft

                Components.NetworkRing {
                    anchors.fill: parent
                    integrityValue: netRoot._signal
                    valueText: Math.round(netRoot._signal * 100) + "%"
                    label: "SIGNAL_INTEGRITY"
                }
            }

            // Right: Metadata cards
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 8

                // PUBLIC_STATIC_IP
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    radius: 6
                    color: Config.ThemeConfig.colors.surfaceContainer || "#111111"
                    border.width: 0

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 0
                        spacing: 0

                        // accent bar
                        Rectangle {
                            width: 3
                            height: parent.height
                            color: Config.ThemeConfig.colors.text || "#ffffff"
                            radius: 1
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            spacing: 1

                            Text {
                                text: "PUBLIC_STATIC_IP"
                                font.pixelSize: 8
                                font.weight: Font.Bold
                                font.letterSpacing: 1.2
                                color: Config.ThemeConfig.colors.textDim || "#808080"
                            }
                            Text {
                                text: netRoot._publicIp
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                font.family: "Monospace"
                                color: Config.ThemeConfig.colors.text || "#ffffff"
                            }
                        }
                    }
                }

                // ASSIGNED_INTERNAL_IP
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    radius: 6
                    color: Config.ThemeConfig.colors.surfaceContainer || "#111111"

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        spacing: 1

                        Text {
                            text: "ASSIGNED_INTERNAL_IP"
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                            color: Config.ThemeConfig.colors.textDim || "#808080"
                        }
                        Text {
                            text: netRoot._ipAddr
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            font.family: "Monospace"
                            color: Config.ThemeConfig.colors.secondary || "#00dce5"
                        }
                    }
                }

                // SERVICE_SET_ID
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    radius: 6
                    color: Config.ThemeConfig.colors.surfaceContainer || "#111111"

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        spacing: 1

                        Text {
                            text: "SERVICE_SET_ID"
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                            color: Config.ThemeConfig.colors.textDim || "#808080"
                        }
                        Text {
                            width: parent.width
                            text: netRoot._ssid.toUpperCase()
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: Config.ThemeConfig.colors.text || "#ffffff"
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
