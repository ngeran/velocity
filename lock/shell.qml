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

ShellRoot {
    id: root

    readonly property bool preview: Quickshell.env("VELOCITY_LOCK_PREVIEW") === "1"

    // ── PREVIEW — plain overlay window on the focused screen, no lock ───────
    PanelWindow {
        visible: root.preview
        color: LockConfig.bg
        exclusiveZone: -1
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
                        Qt.callLater(Qt.quit)   // exit = unlock for hypridle's bookkeeping
                    }
                }
            }
        }
    }
}
