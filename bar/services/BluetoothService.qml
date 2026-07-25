/** Version: 9.1 - Fixed device list separator, empty state, post-toggle refresh **/
pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false

    property bool powered: false
    property int deviceCount: 0
    property string connectedDeviceList: ""   // comma-separated; "" = no devices

    // bluetoothctl presence — when absent we stop polling instead of forking a
    // failing process forever and showing a misleading "OFF" state.
    property bool hasBluetooth: true

    // One-shot presence probe; gates the poll timer on exit.
    Process {
        id: detectProc
        command: ["sh", "-c", "command -v bluetoothctl >/dev/null && bluetoothctl show >/dev/null 2>&1"]
        onExited: function(code) {
            root.hasBluetooth = (code === 0)
            btPollTimer.running = root.hasBluetooth
        }
    }

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
        // Returns one device name per line; we join with comma for TrayCard Repeater
        command: ["sh", "-c", "bluetoothctl devices Connected | cut -d ' ' -f 3-"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { btDevProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                const lines = btDevProc.buffer.trim().split("\n").filter(l => l.trim().length > 0)
                root.deviceCount = lines.length
                root.connectedDeviceList = lines.join(",")   // "" when no devices
                btDevProc.buffer = ""
            }
        }
    }

    Timer {
        id: btPollTimer
        interval: 6000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            if (!btShowProc.running) btShowProc.running = true
            if (!btDevProc.running)  btDevProc.running  = true
        }
    }

    // Re-poll 1 s after toggle so UI reflects the real state quickly
    Timer {
        id: refreshTimer
        interval: 1000; repeat: false
        onTriggered: {
            if (!btShowProc.running) btShowProc.running = true
            if (!btDevProc.running)  btDevProc.running  = true
        }
    }

    function togglePower() {
        Quickshell.exec(["bluetoothctl", "power", root.powered ? "off" : "on"])
        root.powered = !root.powered   // optimistic update
        refreshTimer.restart()
    }

    Component.onCompleted: detectProc.running = true
}
