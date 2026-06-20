// =============================================================================
// HyprlandService.qml — Hyprland workspace state monitoring
// =============================================================================
//
// This singleton service monitors Hyprland workspace state through polling.
// It provides the active workspace ID to UI components.
//
// PROPERTIES
//   activeWorkspace: int — Current active workspace ID (1-based)
//
// METHODS
//   switchTo(id: int) — Switch to workspace by ID
//
// IMPLEMENTATION
//   - Polls `hyprctl activeworkspace -j` every 1.5s
//   - Uses wtype to simulate SUPER + number keypress (workaround for broken dispatchers)
//
// NOTE: In Hyprland 0.55+ with Lua config, standard dispatchers are broken.
// We use wtype to simulate SUPER + number keypresses as a workaround.
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

    property int activeWorkspace: 1

    // =========================================================================
    // WORKSPACE POLLING
    // =========================================================================

    Process {
        id: wsProc
        command: ["bash", "-c", "hyprctl activeworkspace -j 2>&1"]
        property string buffer: ""
        stdout: SplitParser {
            onRead: function(data) { wsProc.buffer += data }
        }
        onRunningChanged: {
            if (!running) {
                try {
                    const obj = JSON.parse(wsProc.buffer)
                    root.activeWorkspace = obj.id || 1
                    console.log("[HyprlandService] Active workspace:", root.activeWorkspace)
                } catch(e) {
                    console.log("[HyprlandService] Parse error:", e, "buffer:", wsProc.buffer)
                }
                wsProc.buffer = ""
            }
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!wsProc.running) wsProc.running = true
        }
    }

    // =========================================================================
    // WORKSPACE SWITCHING (via wtype keypress simulation)
    // =========================================================================

    Process {
        id: switchProc
        property int targetWs: 1
        // Use wtype to simulate SUPER + number keypress
        command: ["bash", "-c", "wtype --key 125 --key " + ((targetWs % 10) + 2).toString() + " --key 125 2>&1"]
        property string buffer: ""
        stdout: SplitParser {
            onRead: function(data) { switchProc.buffer += data }
        }
        onRunningChanged: {
            if (!running) {
                console.log("[HyprlandService] Switch output:", switchProc.buffer.trim())
                switchProc.buffer = ""
            }
        }
    }

    function switchTo(idx: int) {
        console.log("[HyprlandService] Switching to workspace:", idx)
        // Hyprland 0.55+ Lua config: the classic `hyprctl dispatch workspace N`
        // is gone (it now evaluates Lua and errors). The correct form is the
        // Lua dispatcher hl.dsp.focus({ workspace = N }). (The old wtype
        // keypress hack never worked here — wtype isn't even installed.)
        switchProc.command = ["bash", "-c", "hyprctl dispatch 'hl.dsp.focus({ workspace = " + idx + " })' 2>&1"]
        switchProc.running = true
    }

    Component.onCompleted: {
        console.log("[HyprlandService] Service loaded")
    }
}
