// =============================================================================
// shell.qml — velocity-lock entry point (separate config root: `quickshell -c lock`)
// =============================================================================
// Launched by bin/velocity-lock (hypridle lock_cmd / manual). Two modes:
//   REAL (default): WlSessionLock engages at once — one surface per monitor,
//     exclusive keyboard, PAM against the "velocity-lock" service. Success
//     releases the lock and the process exits (hypridle treats exit as unlock).
//   PREVIEW (VELOCITY_LOCK_PREVIEW=1, or `velocity-lock preview`): the same
//     layout in a plain overlay window — nothing is locked, PAM never starts.
//     Non-destructive rendering/auth-flow check; the J3b gate uses the real mode.
// SECURITY NOTE (ext_session_lock_v1): if this process dies mid-lock, the
// session stays locked and INOPERABLE by design — recovery is a TTY +
// `loginctl unlock-session` (misc.allow_session_lock_restore in omni-nix
// lets hyprlock take over instead). bin/velocity-lock refuses to start the
// real mode without /etc/pam.d/velocity-lock, so a PAM-less lock can wedge.
// =============================================================================

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root

    readonly property bool preview: Quickshell.env("VELOCITY_LOCK_PREVIEW") === "1"

    // ── Heartbeat — the watchdog's ground truth (P6.5 fail-safe) ─────────────
    // While a REAL lock is held, write $XDG_RUNTIME_DIR/velocity-lock-state
    // every 5 s: {"locked":<bool>,"screens":<n>,"ts":<epoch-s>}. The watchdog
    // (systemd timer → tools/velocity-lock-watchdog) keys every repair to a
    // live holder + this file, so it can tell a healthy lock from:
    //   · stale ts    → hung event loop (kill + relaunch)
    //   · locked=false while alive → unlock fired but quit hung (kill only —
    //     the session is already open; relaunching would re-lock it)
    //   · locked=true, screens=0, monitor present → the DPMS output-teardown
    //     race: surface died on a removed wl_output, never rebuilt (kill +
    //     relaunch; a FRESH process maps its surface when the output returns).
    // Preview writes nothing — a QA overlay is never a lock holder.
    function _beat() {
        if (root.preview) return       // preview writes nothing — never a holder
        _heartbeat.command = [
            "sh", "-c", 'printf \'%s\' "$2" > "$1.tmp" && mv -f "$1.tmp" "$1"',
            "sh",
            (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/velocity-lock-state",
            JSON.stringify({
                locked: lock.locked,
                screens: Quickshell.screens.length,
                ts: Math.floor(Date.now() / 1000)
            })
        ]
        _heartbeat.running = true
    }
    property Process _heartbeat: Process { command: [] }
    Timer {
        interval: 5000
        repeat: true
        running: !root.preview
        onTriggered: root._beat()
        Component.onCompleted: root._beat()
    }

    // ── PREVIEW — plain overlay window on the focused screen, no lock ───────
    PanelWindow {
        visible: root.preview
        color: LockConfig.bg
        exclusiveZone: -1
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        LockScreen {
            anchors.fill: parent
            preview: true
        }
    }

    // ── REAL — the session lock. `surface` clones per screen (one WlSessionLock-
    // Surface per monitor, documented WlSessionLock behavior).
    WlSessionLock {
        id: lock

        locked: !root.preview

        surface: Component {
            WlSessionLockSurface {
                color: LockConfig.bg

                LockScreen {
                    anchors.fill: parent
                    onUnlockRequested: {
                        lock.locked = false
                        root._beat()            // mark locked=false NOW: if the quit below hangs, the watchdog sees a harmless zombie instead of a wedge
                        Qt.callLater(Qt.quit)   // exit = unlock for hypridle's bookkeeping
                    }
                }
            }
        }
    }
}
