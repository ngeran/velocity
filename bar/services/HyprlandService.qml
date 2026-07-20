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
//   - Streams Hyprland's socket2 event bus via `nc -U` (persistent, event-driven)
//   - One-shot `hyprctl activeworkspace -j` at startup seeds the initial
//     workspace (socket2 only fires on CHANGE, not at connect)
//   - socat is NOT installed on this system, so nc -U is used instead
//
// NOTE: switchTo uses the Lua dispatcher `hl.dsp.focus({ workspace = N })` —
// Hyprland 0.55+ with Lua config dropped the classic `dispatch workspace N`.
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
    // STARTUP SEED — socket2 only fires on CHANGE, not at connect, so read the
    // current workspace once at launch to seed activeWorkspace. ──────────────
    // =========================================================================

    Process {
        id: seedProc
        command: ["bash", "-c", "hyprctl activeworkspace -j 2>&1"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { seedProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                try {
                    var obj = JSON.parse(seedProc.buffer)
                    root.activeWorkspace = obj.id || 1
                    console.log("[HyprlandService] Seeded active workspace:", root.activeWorkspace)
                } catch(e) {
                    console.log("[HyprlandService] Seed parse error:", e, "buffer:", seedProc.buffer)
                }
                seedProc.buffer = ""
            }
        }
    }

    // =========================================================================
    // EVENT STREAM — Hyprland socket2 via nc -U (persistent). Parses
    // workspace>> / workspacev2>> / focusedmon>> and updates activeWorkspace
    // instantly. Replaces the 1.5s hyprctl poll (zero latency, no per-tick
    // fork). socat is NOT installed on this system, so nc -U is used instead
    // (verified to stream socket2). ─────────────────────────────────────────
    // =========================================================================

    Process {
        id: wsWatcher
        // sh -c so the shell expands the runtime/instance-signature env vars.
        command: ["sh", "-c", "nc -U \"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock\""]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var ev = "" + line
                var id = 0
                if (ev.indexOf("workspacev2>>") === 0) {
                    // workspacev2>>id,name
                    id = parseInt(ev.substring("workspacev2>>".length).split(",")[0], 10)
                } else if (ev.indexOf("workspace>>") === 0) {
                    // workspace>>id
                    id = parseInt(ev.substring("workspace>>".length), 10)
                } else if (ev.indexOf("focusedmon>>") === 0) {
                    // focusedmon>>monname,workspaceid
                    id = parseInt(ev.substring("focusedmon>>".length).split(",")[1], 10)
                }
                if (id > 0 && id !== root.activeWorkspace) {
                    root.activeWorkspace = id
                    console.log("[HyprlandService] Active workspace:", root.activeWorkspace)
                }
            }
        }
    }

    // Watchdog: if the socket2 stream ever drops, reconnect + re-seed.
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: { if (!wsWatcher.running) { wsWatcher.running = true; seedProc.running = true } }
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
        seedProc.running = true
    }
}
