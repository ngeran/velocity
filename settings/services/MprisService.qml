// =============================================================================
// MprisService.qml — Media Player (MPRIS) Control Service
// =============================================================================
//
// Manages media playback via playerctl (MPRIS interface).
// Provides play/pause/next/previous controls and current track info.
//
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io

Item {
    id: root

    // =========================================================================
    // MEDIA STATE
    // =========================================================================

    property string player: ""           // Active player name
    property string title: ""            // Track title
    property string artist: ""           // Artist name
    property string album: ""            // Album name
    property string status: "stopped"    // playing, paused, stopped
    property bool canControl: false      // Whether a player is available

    // =========================================================================
    // STATE POLLING
    // =========================================================================

    Timer {
        id: pollTimer
        interval: 1000  // Poll every second
        running: true
        repeat: true
        onTriggered: refreshMetadata()
    }

    Process {
        id: metadataReader

        property string buffer: ""

        command: ["sh", "-c", "playerctl metadata --format '{{playerName}}\t{{status}}\t{{title}}\t{{artist}}\t{{album}}' 2>/dev/null || true"]

        stdout: SplitParser {
            onRead: function(data) {
                metadataReader.buffer += data
            }
        }

        onRunningChanged: {
            if (!running && metadataReader.buffer.length > 0) {
                var lines = metadataReader.buffer.trim().split("\n")
                if (lines.length > 0 && lines[0].length > 0) {
                    var parts = lines[0].split("\t")
                    if (parts.length >= 5) {
                        root.player = parts[0]
                        root.status = parts[1].toLowerCase()
                        root.title = parts[2]
                        root.artist = parts[3]
                        root.album = parts[4]
                        root.canControl = true
                    }
                } else {
                    // No player active
                    root.canControl = false
                    root.status = "stopped"
                }
                metadataReader.buffer = ""
            }
        }
    }

    // =========================================================================
    // PLAYBACK CONTROLS
    // =========================================================================

    Process {
        id: controlRunner
        command: []
        running: false
    }

    function playPause() {
        if (!root.canControl) return
        controlRunner.command = ["sh", "-c", "playerctl play-pause 2>/dev/null || true"]
        controlRunner.running = true
        // Refresh metadata after control
        Qt.callLater(function() { refreshMetadata() })
    }

    function next() {
        if (!root.canControl) return
        controlRunner.command = ["sh", "-c", "playerctl next 2>/dev/null || true"]
        controlRunner.running = true
        Qt.callLater(function() { refreshMetadata() })
    }

    function previous() {
        if (!root.canControl) return
        controlRunner.command = ["sh", "-c", "playerctl previous 2>/dev/null || true"]
        controlRunner.running = true
        Qt.callLater(function() { refreshMetadata() })
    }

    function stop() {
        if (!root.canControl) return
        controlRunner.command = ["sh", "-c", "playerctl stop 2>/dev/null || true"]
        controlRunner.running = true
        Qt.callLater(function() { refreshMetadata() })
    }

    // =========================================================================
    // PUBLIC API
    // =========================================================================

    function refreshMetadata() {
        metadataReader.running = true
    }

    function getTrackInfo() {
        if (!root.canControl) return "No player active"
        var info = ""
        if (root.title.length > 0) info = root.title
        if (root.artist.length > 0) {
            if (info.length > 0) info += " · "
            info += root.artist
        }
        return info.length > 0 ? info : "No track info"
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    Component.onCompleted: {
        console.log("[MprisService] Starting media control")
        refreshMetadata()
    }
}
