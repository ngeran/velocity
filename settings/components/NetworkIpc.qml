// =============================================================================
// NetworkIpc.qml — IPC surface for the NETWORK section (scripting / probes)
// =============================================================================
// Component-owned like DisplayIpc: NetworkControlService is a "../services"
// singleton, and shell.qml's "services" import is a separate instance (the
// SharedState trap). Declared in tools/ipc-surface.txt.
//
//   quickshell ipc -c settings call network latency
//   quickshell ipc -c settings call network engineer
// =============================================================================

import Quickshell.Io
import "../services" as Services

IpcHandler {
    target: "network"

    // Two-leg latency snapshot: per-leg folds (netstats.mjs math) + the
    // paired WAN leg. Nulls when a leg has no data yet.
    function latency(): string {
        var svc = Services.NetworkControlService
        return JSON.stringify({
            connected: svc.connectionStatus.connected === true,
            iface: svc.connectionStatus.iface || "",
            gateway: svc.connectionStatus.gateway || "",
            wan: svc.wanFold,            // {p50,p75,p95,jitter,lossPct,felt,n,...}
            local: svc.localFold,
            wanLegMs: svc.wanLegMs >= 0 ? svc.wanLegMs : null,
            wanLegNote: svc.wanLegNote,
            wanLeg: svc.wanLegFold
        })
    }

    // ENGINEER-pane snapshot: link/PHY, addressing, routes, counters,
    // neighbors, listeners (whatever the last 15s probe collected).
    function engineer(): string {
        var svc = Services.NetworkControlService
        return JSON.stringify({
            iface: svc.connectionStatus.iface || "",
            link: svc.engLink,
            addr: svc.engAddr,
            stats: svc.ifaceStats,
            routes: svc.engRoutes,
            neighbors: svc.engNeighbors,
            listeners: svc.engListeners,
            sampledAt: svc.engRefreshedAt
        })
    }
}
