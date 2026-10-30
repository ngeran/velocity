// =============================================================================
// NetworkIpc.qml — NETWORK-section probe payloads (scripting / truth probes)
// =============================================================================
// P2.1: this no longer declares an IpcHandler — in the merged bar process the
// `network` target is owned by bar/shell.qml (its speedtest verb), and a
// second handler for the same target would silently lose the registration.
// The two payload builders live here (they read the merged network service
// via HostBridge — import-split law: no "../bar" imports) and are exposed through
// SettingsBootstrap; bar/shell.qml's network target forwards to them.
//
//   qs -c bar ipc call network latency
//   qs -c bar ipc call network engineer
// =============================================================================

import QtQuick
import "../services" as Services

QtObject {
    // Two-leg latency snapshot: per-leg folds (netstats.mjs math) + the
    // paired WAN leg. Nulls when a leg has no data yet.
    function latency(): string {
        var svc = Services.HostBridge.network
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
        var svc = Services.HostBridge.network
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
