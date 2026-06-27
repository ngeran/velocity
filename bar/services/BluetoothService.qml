/** Version: 9.0 - Attempting to fix positioning and data fetch **/
pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false

    property bool powered: false
    property int deviceCount: 0
    property string connectedDeviceList: "None"

    Process {
        id: btShowProc
        command: ["bluetoothctl", "show"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { btShowProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                root.powered = btShowProc.buffer.indexOf("Powered: yes") !== -1
                btShowProc.buffer = ""
            }
        }
    }

    Process {
        id: btDevProc
        command: ["sh", "-c", "bluetoothctl devices Connected | cut -d ' ' -f 3-"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { btDevProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                const lines = btDevProc.buffer.trim().split("\n").filter(l => l.length > 0)
                root.deviceCount = lines.length
                root.connectedDeviceList = lines.length > 0 ? lines.join("\n") : "No devices connected"
                btDevProc.buffer = ""
            }
        }
    }

    Timer {
        interval: 6000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            if (!btShowProc.running) btShowProc.running = true
            if (!btDevProc.running) btDevProc.running = true
        }
    }

    function togglePower() {
        Quickshell.exec(["bluetoothctl", "power", root.powered ? "off" : "on"])
        root.powered = !root.powered // Optimistic update
    }
}
