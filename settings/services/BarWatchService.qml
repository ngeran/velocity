// =============================================================================
// BarWatchService.qml — bar liveness watcher (failure-banner data source)
// =============================================================================
// The bar cannot paint its own crash (the T2 duplicate-method incident: a
// config that fails to load = blank bar + dead shortcuts until fixed by
// hand). The SETTINGS process outlives bar failures, so it watches the bar
// and feeds BarFailureBanner.
//
// Detection is SYSTEMD-authoritative — two drill-proven dead ends led here:
//   ✗ instance.lock deletion  : the file is NEVER removed on exit (stale
//     by-id dirs persist — why ryoku's daemon prunes them), and
//     FileView.onFileChanged does not fire on deletion in this build anyway.
//   ✗ flock on instance.lock  : a LIVE quickshell does not hold the flock
//     (`flock -n` acquires it on a healthy bar — probed 5/5 DEAD).
//   ✓ systemd IS the supervisor: MainPID → by-pid symlink → the bar's
//     instance dir. Unit dead / restarting-wait → no pid → failure.
//
// Cadence: one sh probe (systemctl+readlink) every 45s while healthy
// (~1.3 forks/min — noise vs the 110/min pre-native baseline); every 2s
// while the bar is down (banner up, forks fine); journal-tail probe once
// per failure onset. All transitions journal-log — the drill-proof signal.
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false

    readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000") + "/quickshell"

    property bool barAlive: true       // optimistic until proven otherwise
    property string failedSince: ""    // ISO time of failure onset
    property string errorTail: ""      // last journal lines (probed on onset)
    property string barLockPath: ""    // informational: watched instance dir

    function _log(msg) {
        console.log("[BarWatch] " + msg)
    }

    // ── the ONE probe: systemd MainPID → by-pid symlink → instance dir ──────
    // DEV MODE — the unit doesn't exist at all (`quickshell -p` testing, no
    // omni-nix deployment). Nothing to watch, so the banner never shows and
    // the poll drops to the slow cadence; the watch itself is inert.
    property bool devMode: false

    function resolveBar() {
        resolverProc.running = true
    }

    Process {
        id: resolverProc
        command: ["sh", "-c",
            "systemctl --user cat quickshell-bar >/dev/null 2>&1 || { echo DEV-MODE; exit 0; }; " +
            "pid=$(systemctl --user show -p MainPID --value quickshell-bar 2>/dev/null); " +
            "[ -n \"$pid\" ] && [ \"$pid\" != \"0\" ] && readlink \"" + root.runtimeDir + "/by-pid/$pid\" 2>/dev/null || true"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { resolverProc.buffer += data } }
        onStarted: buffer = ""
        onExited: {
            var out = resolverProc.buffer.trim()
            resolverProc.buffer = ""
            if (out === "DEV-MODE") {
                if (!root.devMode) root._log("dev mode — no quickshell-bar unit, watch inert")
                root.devMode = true
                root._setAlive(true)   // nothing to fail; keep the banner hidden
                return
            }
            root.devMode = false
            if (out.length === 0) {
                root._setAlive(false)   // unit dead or in RestartSec wait
                return
            }
            if (out !== root.barLockPath) {
                root.barLockPath = out
                root._log("bar instance: " + out)
            }
            root._setAlive(true)
        }
    }

    function _setAlive(alive) {
        if (alive === root.barAlive) return
        if (!alive) {
            root.failedSince = new Date().toISOString()
            root._log("BAR OFFLINE — failure detected")
            errorProbe.running = true
        } else {
            root._log("bar recovered — banner cleared")
        }
        root.barAlive = alive
    }

    // One-shot error tail on failure onset (failure path: a fork is fine).
    Process {
        id: errorProbe
        command: ["sh", "-c",
            "journalctl --user -u quickshell-bar -n 3 --no-pager -o cat 2>/dev/null | tail -n 3"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { errorProbe.buffer += data } }
        onStarted: buffer = ""
        onExited: {
            root.errorTail = errorProbe.buffer.trim()
            errorProbe.buffer = ""
        }
    }

    // ── cadence ──────────────────────────────────────────────────────────────
    // Healthy: 45s bounding poll. Down: 2s until a stable pid reappears.
    Timer {
        interval: 45000
        running: root.barAlive
        repeat: true
        onTriggered: root.resolveBar()
    }
    Timer {
        interval: 2000
        running: !root.barAlive
        repeat: true
        onTriggered: root.resolveBar()
    }

    Component.onCompleted: {
        root._log("startup resolve")
        root.resolveBar()
    }
}
