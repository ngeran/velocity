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
    // STATUS PROBE — polls wpctl for volume + mute state
    // Output: "Volume: 0.40" (+ " [MUTED]" when muted)
    // -------------------------------------------------------------------------
    Process {
        id: statusProc
        command: ["wpctl", "get-volume", "@DEFAULT_SINK@"]
        property string buffer: ""
        stdout: SplitParser {
            onRead: data => {
                if (root.syncLock) return
                statusProc.buffer += data
            }
        }
        onRunningChanged: {
            if (!running) {
                // wpctl prints "Volume: 0.40" (decimal 0-1); [MUTED] if muted
                const volMatch = statusProc.buffer.match(/Volume:\s*([\d.]+)/)
                if (volMatch) root.volume = Math.round(parseFloat(volMatch[1]) * 100)
                root.muted = statusProc.buffer.indexOf("[MUTED]") !== -1
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

    // Lock expires after 1.5 s — enough for wpctl to settle
    Timer {
        id: lockTimeout
        interval: 1500
        onTriggered: {
            root.syncLock = false
            if (!statusProc.running) statusProc.running = true
        }
    }

    // -------------------------------------------------------------------------
    // VOLUME PROCESS — wpctl set-volume (command set dynamically before running)
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
    // MUTE PROCESS — wpctl set-mute toggle
    // -------------------------------------------------------------------------
    Process {
        id: muteProc
        command: ["wpctl", "set-mute", "@DEFAULT_SINK@", "toggle"]
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
        // wpctl takes a decimal fraction (0.00-1.00); -l 1.0 caps at 100%
        volumeProc.command = ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_SINK@", (root.volume / 100).toFixed(2)]
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
