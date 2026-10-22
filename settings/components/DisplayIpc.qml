// =============================================================================
// DisplayIpc.qml — IPC surface for the Display section (truth probes / CLI)
// =============================================================================
// Lives in components/ on purpose: MonitorService is a "../services" singleton,
// and shell.qml's "services" import is a SEPARATE instance (the SharedState
// trap — see ModernDashboard). A shell.qml-side handler would probe an empty
// twin. Declared in tools/ipc-surface.txt.
//
//   quickshell ipc -c settings call display status
//   quickshell ipc -c settings call display stage
// =============================================================================

import Quickshell.Io
import "../services" as Services

IpcHandler {
    target: "display"

    function status(): string {
        var ms = Services.MonitorService.monitors
        var t = Services.MonitorService.target
        return JSON.stringify({
            monitors: ms.length,
            "target": t ? t.name : "",   // quoted: a bare `target:` here re-triggers the ipc extractor
            targetDesc: t ? t.desc : "",
            stagedKey: t ? Services.MonitorService._outputKeyFor(t) : "",
            identityCollided: Services.MonitorService.identityCollided,
            persistState: Services.MonitorService.persistState,
            vrrMode: Services.MonitorService.vrrMode,
            live: t ? { mode: Services.MonitorService.currentModeString(),
                       scale: String(t.scale), bitdepth: String(Services.MonitorService.liveBitdepth()) } : null
        })
    }

    function stage(): string {
        Services.MonitorService.stageToNix()
        return "staging"
    }

    function refresh(): string {
        Services.MonitorService.refresh()
        return "polling"
    }

    // Keep/Revert cycle probe (no visible change): stages the CURRENT rule
    // through applyWithRevert({}, …) — exercises the snapshot, the banner,
    // and the external systemd revert timer. Pair with
    // `systemctl --user list-timers | grep velocity-display-revert` and
    // display.revertState / display.revertKeep.
    function revertProbe(): string {
        Services.MonitorService.applyWithRevert("PROBE keep/revert cycle", {})
        return revertState()
    }

    function revertState(): string {
        var pr = Services.MonitorService.pendingRevert
        return pr ? JSON.stringify({ label: pr.label,
                                     secondsLeft: Services.MonitorService.revertSecondsLeft })
                  : "none"
    }

    function revertKeep(): string {
        Services.MonitorService.confirmKeep()
        return revertState()
    }

    // Synthetic-topology assertions for the twin-EDID keying (no dual-display
    // hardware required). Returns PASS or the failing list.
    function selftest(): string {
        return Services.MonitorService.selfTest()
    }
}
