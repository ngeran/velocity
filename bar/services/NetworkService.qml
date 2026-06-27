/** Version: 9.0 - Added SSID and IP parsing **/
pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false

    property string connectionType: ""
    property bool isConnected: false
    property string ssid: "Disconnected"
    property string ipAddress: "0.0.0.0"

    Process {
        id: netProc
        // Fetches SSID and IP Address in one pass
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE,CONNECTION device | grep -E '^(wifi|ethernet):connected' | head -1; ip -4 route get 1 2>/dev/null | grep -oE 'src [0-9.]+' | awk '{print $2}'"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { netProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                const lines = netProc.buffer.trim().split("\n")
                if (lines.length >= 1 && lines[0].includes(":connected")) {
                    const parts = lines[0].split(":")
                    root.connectionType = parts[0]
                    root.ssid = parts[2] || "Connected"
                    root.isConnected = true
                    root.ipAddress = lines[1] || "No IP"
                } else {
                    root._reset()
                }
                netProc.buffer = ""
            }
        }
    }

    Timer {
        interval: 4000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: if (!netProc.running) netProc.running = true
    }

    function _reset() {
        root.connectionType = ""
        root.isConnected = false
        root.ssid = "Disconnected"
        root.ipAddress = "0.0.0.0"
    }
}
