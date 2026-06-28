/** Version: 8.0 - Replaced Quickshell.exec() with Process objects (exec doesn't exist) **/
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property int volume: 0
    property bool muted: false
    property bool syncLock: false

    // -------------------------------------------------------------------------
    // STATUS PROBE — polls pactl for volume + mute state
    // -------------------------------------------------------------------------
    Process {
        id: statusProc
        command: ["sh", "-c", "pactl get-sink-volume @DEFAULT_SINK@; pactl get-sink-mute @DEFAULT_SINK@"]
        property string buffer: ""
        stdout: SplitParser {
            onRead: data => {
                if (root.syncLock) return
                statusProc.buffer += data
            }
        }
        onRunningChanged: {
            if (!running) {
                const volMatch = statusProc.buffer.match(/(\d+)%/)
                if (volMatch) root.volume = parseInt(volMatch[1])
                if (statusProc.buffer.includes("Mute:"))
                    root.muted = statusProc.buffer.includes("Mute: yes")
                statusProc.buffer = ""
            }
        }
    }

    // Poll every 2.5 s; skip if locked or already running
    Timer {
        interval: 2500; running: true; repeat: true
        onTriggered: {
            if (!root.syncLock && !statusProc.running)
                statusProc.running = true
        }
    }

    // Lock expires after 1.5 s — enough for pactl to settle
    Timer {
        id: lockTimeout
        interval: 1500
        onTriggered: {
            root.syncLock = false
            if (!statusProc.running) statusProc.running = true
        }
    }

    // -------------------------------------------------------------------------
    // VOLUME PROCESS — pactl set-sink-volume
    // command is set dynamically before running = true
    // -------------------------------------------------------------------------
    Process {
        id: volumeProc
        property string buffer: ""
        stderr: SplitParser { onRead: data => { volumeProc.buffer += data } }
        onRunningChanged: {
            if (!running) volumeProc.buffer = ""
        }
    }

    // -------------------------------------------------------------------------
    // MUTE PROCESS — pactl set-sink-mute toggle
    // -------------------------------------------------------------------------
    Process {
        id: muteProc
        command: ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"]
        property string buffer: ""
        stderr: SplitParser { onRead: data => { muteProc.buffer += data } }
        onRunningChanged: {
            if (!running) muteProc.buffer = ""
        }
    }

    // -------------------------------------------------------------------------
    // PUBLIC API
    // -------------------------------------------------------------------------
    function setVolume(val) {
        if (volumeProc.running) return   // don't stack calls mid-drag
        root.syncLock = true
        lockTimeout.restart()
        root.volume = Math.max(0, Math.min(100, Math.round(val)))
        volumeProc.command = ["pactl", "set-sink-volume", "@DEFAULT_SINK@", root.volume + "%"]
        volumeProc.running = true
    }

    function toggleMute() {
        if (muteProc.running) return
        root.syncLock = true
        lockTimeout.restart()
        root.muted = !root.muted
        muteProc.running = true
    }

    function volumeUp()   { setVolume(Math.min(root.volume + 5, 100)) }
    function volumeDown() { setVolume(Math.max(root.volume - 5, 0))   }
}
