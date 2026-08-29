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
//   - THE socket2 owner for the bar: every raw event line is re-emitted on
//     socketEvent(line) so other services subscribe instead of opening their
//     own nc consumer (KeyboardService held a second stream before).
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

    // Raw socket2 line, re-emitted for subscriber services (KeyboardService).
    signal socketEvent(string line)

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
                root.socketEvent(ev)   // subscribers first, then our own parse
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
    // WORKSPACE SWITCHING — Hyprland 0.55+ Lua dispatcher (hl.dsp.focus)
    // =========================================================================

    // Bare runner: switchTo() builds the hyprctl dispatch command inline.
    Process { id: switchProc }

    function switchTo(idx: int) {
        console.log("[HyprlandService] Switching to workspace:", idx)
        OsdService.showWorkspace(idx, "")   // feedback for bar-initiated switches
        // Hyprland 0.55+ Lua config dropped `hyprctl dispatch workspace N`
        // (it now evaluates Lua and errors). Use the Lua dispatcher form.
        switchProc.command = ["bash", "-c", "hyprctl dispatch 'hl.dsp.focus({ workspace = " + idx + " })' 2>&1"]
        switchProc.running = true
    }

    Component.onCompleted: {
        console.log("[HyprlandService] Service loaded")
        seedProc.running = true
    }
}
