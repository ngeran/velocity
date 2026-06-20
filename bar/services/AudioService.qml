// =============================================================================
// AudioService.qml — Audio volume monitoring
// =============================================================================
//
// This singleton service monitors PipeWire audio volume state.
//
// PROPERTIES
//   muted: bool — True when default audio sink is muted
//   volume: int — Current volume level (0-100)
//
// METHODS
//   toggleMute() — Toggle mute state
//   volumeUp() — Increase volume by 5%
//   volumeDown() — Decrease volume by 5%
//
// IMPLEMENTATION
//   - Polls pactl for volume/mute state every 3s
//   - Uses pactl/wpctl for volume adjustments
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false

    // =========================================================================
    // PUBLIC PROPERTIES
    // =========================================================================

    property bool muted: false
    property int volume: 0
    property string defaultSink: ""

    // =========================================================================
    // FIND DEFAULT SINK
    // =========================================================================

    Process {
        id: findSinkProc
        command: ["pactl", "get-default-sink"]
        property string buffer: ""
        stdout: SplitParser {
            onRead: function(data) { findSinkProc.buffer += data }
        }
        onRunningChanged: {
            if (!running) {
                root.defaultSink = findSinkProc.buffer.trim()
                findSinkProc.buffer = ""
            }
        }
    }

    // =========================================================================
    // VOLUME POLLING
    // =========================================================================

    Process {
        id: volProc
        command: ["pactl", "get-sink-volume", "@DEFAULT_SINK@"]
        property string buffer: ""
        stdout: SplitParser {
            onRead: function(data) { volProc.buffer += data }
        }
        onRunningChanged: {
            if (!running) {
                const line = volProc.buffer.trim()
                // Parse volume from "Volume: front-left: 65536 /  100% / 0.00 dB"
                const match = line.match(/(\d+)%/)
                if (match) {
                    root.volume = parseInt(match[1])
                }
                volProc.buffer = ""
            }
        }
    }

    Process {
        id: muteProc
        command: ["pactl", "get-sink-mute", "@DEFAULT_SINK@"]
        property string buffer: ""
        stdout: SplitParser {
            onRead: function(data) { muteProc.buffer += data }
        }
        onRunningChanged: {
            if (!running) {
                const line = muteProc.buffer.trim()
                root.muted = line.indexOf("yes") !== -1
                muteProc.buffer = ""
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!findSinkProc.running) findSinkProc.running = true
            if (!volProc.running) volProc.running = true
            if (!muteProc.running) muteProc.running = true
        }
    }

    // =========================================================================
    // VOLUME CONTROLS
    // =========================================================================

    Process {
        id: toggleMuteProc
        command: ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"]
    }

    Process {
        id: volUpProc
        command: ["pactl", "set-sink-volume", "@DEFAULT_SINK@", "+5%"]
    }

    Process {
        id: volDownProc
        command: ["pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%"]
    }

    function toggleMute() {
        toggleMuteProc.running = true
    }

    function volumeUp() {
        volUpProc.running = true
    }

    function volumeDown() {
        volDownProc.running = true
    }
}
