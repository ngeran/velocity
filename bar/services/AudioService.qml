/** Version: 7.0 **/
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
        running: true
        stdout: SplitParser {
            onRead: data => {
                // If we recently touched the UI, ignore the system's "old" status reports
                if (root.syncLock) return; 
                
                const volMatch = data.match(/(\d+)%/);
                if (volMatch) root.volume = parseInt(volMatch[1]);
                
                if (data.includes("Mute:")) {
                    root.muted = data.includes("yes");
                }
            }
        }
    }

    // Polling timer
    Timer {
        interval: 2500; running: true; repeat: true
        onTriggered: if (!root.syncLock) statusProc.running = true
    }

    // V7: Increased to 5 seconds to ensure pactl updates fully
    Timer {
        id: lockTimeout
        interval: 5000 
        onTriggered: {
            root.syncLock = false;
            statusProc.running = true; // Refresh now that lock is over
        }
    }

    function setVolume(val) {
        root.syncLock = true;
        lockTimeout.restart();
        root.volume = Math.round(val);
        Quickshell.exec(["pactl", "set-sink-volume", "@DEFAULT_SINK@", root.volume + "%"]);
    }

    function toggleMute() {
        root.syncLock = true;
        lockTimeout.restart();
        root.muted = !root.muted;
        Quickshell.exec(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"]);
    }

    function volumeUp() { setVolume(Math.min(root.volume + 5, 100)); }
    function volumeDown() { setVolume(Math.max(root.volume - 5, 0)); }
}
