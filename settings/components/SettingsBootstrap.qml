// =============================================================================
// SettingsBootstrap.qml — the always-on settings-tree foothold in the bar
// process (P2.1). The bar shell loads this via file:// at boot, so that:
//
//   • the settings-side singletons that must be alive for the PROCESS
//     lifetime (not just while the dashboard is open) get pinned:
//     SystemMetricsService (deepcool LCD feed) and WallpaperService
//     (wallpaper-service IPC).
//   • component-owned IPC surfaces that must answer without the window
//     (DisplayIpc, NetworkIpc) are instantiated here — they read the same
//     services the views use (import-split law; bar services via HostBridge).
//   • bar-config write verbs (setBarStyle/…) live here as plain functions:
//     the bar's SettingsWindow IPC target forwards them, and they must work
//     with the dashboard window never having been opened.
//
// The bar shell hands its services over via barServices → HostBridge.attach.
// =============================================================================

import QtQuick
import "../config" as Config
import "../services" as Services

Item {
    id: bootstrap

    width: 0
    height: 0

    // Assigned by bar/shell.qml once the loader settles; funnels into the
    // HostBridge singleton the views read. Reassigned, never mutated.
    property var barServices: null
    onBarServicesChanged: {
        if (barServices) Services.HostBridge.attach(barServices)
    }

    // ── NetworkService lease mirror (P2.2) ──────────────────────────────────
    // The merged network service lives in the bar tree and cannot read
    // SharedState (import-split law), so its dashboard/section gates are
    // plain bool properties pushed from here — on attach and on every
    // visibility/section change.
    function _pushNetworkLeases() {
        var n = Services.HostBridge.network
        if (!n) return
        n.dashboardLease = Config.SharedState.dashboardVisible
        n.sectionLease = Config.SharedState.dashboardVisible
                      && Config.SharedState.controlSection === "network"
    }
    Connections {
        target: Services.HostBridge
        function onBarChanged() { bootstrap._pushNetworkLeases() }
    }
    Connections {
        target: Config.SharedState
        function onDashboardVisibleChanged() { bootstrap._pushNetworkLeases() }
        function onControlSectionChanged()   { bootstrap._pushNetworkLeases() }
    }

    Component.onCompleted: {
        // (The old SystemMetricsService pin is gone — P2.3 merged metrics into
        // the bar's MetricsService, pinned by bar/shell.qml's boot handler.)

        // Member read forces the lazy singleton (a bare reference is dead
        // code to the JS engine — see bar/shell.qml's _notificationSvcPin).
        // Its IpcHandler only registers once the singleton exists, and
        // wallpaper IPC must answer without the dashboard ever having been
        // opened (SUPER+SHIFT+W cycle).
        Services.WallpaperService.wallpaperList
    }

    // Display-section IPC (status/stage probes) — component-owned so it reads
    // the "../services" MonitorService instance.
    DisplayIpc { }

    // Network-section probe payloads (latency/engineer) — the `network` IPC
    // target itself is owned by bar/shell.qml (speedtest); these builders are
    // forwarded through networkLatency/networkEngineer below.
    NetworkIpc { id: networkIpc }

    function networkLatency(): string { return networkIpc.latency() }
    function networkEngineer(): string { return networkIpc.engineer() }

    // ── C4: bar-owned keys written FROM the bar surfaces (BarSettingsBody
    // picks; the old velocity.bar-settings overlay was deleted in P4.8) ──────
    // Moved verbatim from the old settings/shell.qml SettingsWindow IpcHandler
    // (P2.1). They stay silent writes: no window is opened. Since P2.5 they
    // hand the validated change straight to the bar's BarConfigWriter (one
    // process, one writer) and refresh the settings-side mirror.
    function _barMerge(change) {
        var w = Services.HostBridge.configWriter
        if (!w) return "error: bar config writer not ready (bar shell not attached)"
        w.merge(change)
        return "ok"
    }

    function setBarStyle(name: string): string {
        if (!/^[a-z0-9][a-z0-9-]*$/.test(String(name)))
            return "error: style name must match [a-z0-9-]"
        Services.SettingsConfigService.barStyle = String(name)
        return _barMerge({ barStyle: String(name) })
    }

    function setBarPosition(pos: string): string {
        if (pos !== "top" && pos !== "bottom")
            return "error: position must be top|bottom"
        Services.SettingsConfigService.barPosition = String(pos)
        return _barMerge({ barPosition: String(pos) })
    }

    // J5: OSD track style — same silent funnel as style/edge.
    function setOsdStyle(style: string): string {
        if (style !== "bar" && style !== "segments" && style !== "edge")
            return "error: osd style must be bar|segments|edge"
        Services.SettingsConfigService.osdStyle = String(style)
        return _barMerge({ osdStyle: String(style) })
    }

    function setBarHeight(h: string): string {
        var v = Math.round(Number(h))
        if (!(v >= 18 && v <= 64))
            return "error: height must be an int 18..64"
        Services.SettingsConfigService.barHeight = v
        return _barMerge({ barHeight: v })
    }

    function setWorkspaceCount(n: string): string {
        var v = Math.round(Number(n))
        if ([3, 5, 7, 9].indexOf(v) === -1)
            return "error: workspace count must be 3|5|7|9"
        Services.SettingsConfigService.workspaceCount = v
        return _barMerge({ workspaceCount: v })
    }

    // scope: "strip" (vector/notch/ryoku BurnOrbit) | "island" (island
    // dim/orbit clock) — two knobs because the island's guard also dims.
    function setBurnGuard(scope: string, val: string): string {
        if (scope !== "strip" && scope !== "island")
            return "error: scope must be strip|island"
        if (val !== "on" && val !== "off")
            return "error: val must be on|off"
        var change = {}
        if (scope === "strip") {
            Services.SettingsConfigService.stripBurnGuard = (val === "on")
            change.stripBurnGuard = (val === "on")
        } else {
            Services.SettingsConfigService.islandBurnGuard = (val === "on")
            change.islandBurnGuard = (val === "on")
        }
        return _barMerge(change)
    }

    // ── plugin pipeline (install/convert from the CLI and tests) ────────────
    function pluginInstallFromGit(url: string): string {
        Services.PluginManagerService.installGit(url)
        return "installing"
    }

    function pluginRefresh(): string {
        return JSON.stringify(Services.PluginManagerService.plugins)
    }
}
