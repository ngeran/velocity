/** Version: 9.2 - Prefixed key=value output eliminates separator ambiguity **/
pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false

    property string connectionType: ""
    property bool isConnected: false
    property string ssid: ""
    property string ipAddress: ""

    Process {
        id: netProc
        // Each value printed with an unambiguous prefix — order-independent parsing
        command: ["sh", "-c", [
            "DEV=$(nmcli -t -f TYPE,STATE,CONNECTION device | grep -E '^(wifi|ethernet):connected' | head -1);",
            "[ -z \"$DEV\" ] && exit 0;",
            "TYPE=$(echo \"$DEV\" | cut -d: -f1);",
            "SSID=$(echo \"$DEV\" | cut -d: -f3-);",
            "IP=$(ip -4 route get 1 2>/dev/null | grep -oE 'src [0-9.]+' | awk '{print $2}');",
            "echo \"TYPE=$TYPE\";",
            "echo \"SSID=$SSID\";",
            "echo \"IP=$IP\""
        ].join(" ")]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { netProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                const lines = netProc.buffer.trim().split("\n")
                if (lines.length > 0 && lines[0] !== "") {
                    let type = "", ssid = "", ip = ""
                    for (const line of lines) {
                        if (line.startsWith("TYPE=")) type = line.slice(5).trim()
                        else if (line.startsWith("SSID=")) ssid = line.slice(5).trim()
                        else if (line.startsWith("IP="))   ip   = line.slice(3).trim()
                    }
                    root.connectionType = type
                    root.ssid           = ssid
                    root.ipAddress      = ip
                    root.isConnected    = true
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
        root.isConnected    = false
        root.ssid           = ""
        root.ipAddress      = ""
    }
}
