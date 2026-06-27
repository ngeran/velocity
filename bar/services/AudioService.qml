/** Version: 7.1 - Reduced syncLock timeout, guarded process re-entry **/
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property int volume: 0
    property bool muted: false
    property bool syncLock: false

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

    // Lock expires after 1.5 s — enough for pactl to settle, short enough to feel responsive
    Timer {
        id: lockTimeout
        interval: 1500
        onTriggered: {
            root.syncLock = false
            if (!statusProc.running) statusProc.running = true
        }
    }

    function setVolume(val) {
        root.syncLock = true
        lockTimeout.restart()
        root.volume = Math.round(val)
        Quickshell.exec(["pactl", "set-sink-volume", "@DEFAULT_SINK@", root.volume + "%"])
    }

    function toggleMute() {
        root.syncLock = true
        lockTimeout.restart()
        root.muted = !root.muted
        Quickshell.exec(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"])
    }

    function volumeUp()   { setVolume(Math.min(root.volume + 5, 100)) }
    function volumeDown() { setVolume(Math.max(root.volume - 5, 0))   }
}
