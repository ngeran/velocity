// =============================================================================
// TelemetryTab.qml — tab 1: TELEMETRY + LCD (the instrument cluster)
// =============================================================================
// Split out of SystemInfoTab on 2026-11-03 (user call: "the SYS INFO pane has
// the Dashboard and the Telemetry + LCD — split them"): the former CORE ›
// SYSTEM cluster had been dissolved into the bottom of the dashboard scroll;
// it is now a first-class heavy tab again. What moved 1:1:
//   • the fixed CoreSystemPane band (load 128 + hero + LCD 348 + precision
//     fill — 932px since the pane's own header rail came out, see below)
//   • the coreVisible telemetry grant (below — still the ONLY switch for
//     MetricsService's dmonLoop, history rings and per-core rows)
// The dashboard keeps its cards and its own 45s metrics lease; this tab holds
// its own lease while shown (the two kicks are additive — Lease.acquire
// extends whichever end is later), so either tab feeds independently.
//
// GRANT LIFECYCLE: onLoaded flips coreVisible on; the loader binding flips it
// off on window-hide, and Component.onDestruction covers the destroy path
// (leaving the tab past the fade grace, or the host idle-unload) — a plain
// Loader-destruction emits no activeChanged, which is exactly how the old
// embedded copy could have leaked the grant past a tab switch.
//
// Deep links: openCore system|lcd land HERE (SettingsWindowShell.openCoreTab);
// openCore events still remaps to the Logs tab's EVENTS view. The search
// palette entry moved with it ("telemetry:cluster" → tab "telemetry").
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "." as Components
import "../config" as Config
import "../services" as Services

Item {
    id: root

    // ── window edge + bar bridge (null until the bar shell attaches) ──────
    readonly property bool shown: Config.SharedState.dashboardVisible
    readonly property var m: Services.HostBridge.metrics

    // ── HUD token (fixed instrument language, theme-independent) ──────────
    // (only the backdrop grid needs one; the tab carries no header chrome)
    readonly property color cBorder: Config.HudConfig.borderLo

    // =========================================================================
    // METRICS KICK — lease while shown (same edges as SystemInfoTab: the
    // reliable signals are the WINDOW shown state and tab re-entry, never
    // `visible` alone — the blank-dashboard incident).
    // =========================================================================
    Component.onCompleted: if (shown) root._kickMetrics()
    onShownChanged:    if (shown) root._kickMetrics()
    onVisibleChanged:  if (visible && shown) root._kickMetrics()
    onMChanged:        if (shown && visible) root._kickMetrics()
    function _kickMetrics() {
        if (!m) return
        m.extendLease(45)
        m.refresh()
        m.refreshUptime()
    }
    Timer {
        interval: 20000
        running: root.shown && root.visible && root.m !== null
        repeat: true
        onTriggered: if (root.m) root.m.extendLease(45)
    }

    // =========================================================================
    // BACKDROP GRID (the System-Info family decoration, dimmed)
    // =========================================================================
    Item {
        anchors.fill: parent
        opacity: 0.15
        Repeater {
            model: Math.floor(root.width / 40)
            Rectangle { width: 1; height: root.height; x: index * 40; color: root.cBorder }
        }
        Repeater {
            model: Math.floor(root.height / 40)
            Rectangle { height: 1; width: root.width; y: index * 40; color: root.cBorder }
        }
    }

    // =========================================================================
    // CONTENT — the cluster band, edge to edge, FIXED (user call 2026-11-03:
    // no scrolling on this page). No tab header (the sidebar label + window
    // header already name the view) and the pane's own [A] header rail came
    // out with them. The band fills the viewport EXACTLY — the pane's [E]
    // precision quarters are its flex band and absorb the delta, so the [F]
    // footer rail never clips; only a truly shrunken window clips.
    // =========================================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.ControlConfig.space4
        clip: true
        spacing: 0

        // The grant is the load-bearing part: coreVisible is the
        // ONLY switch for MetricsService's dmonLoop (nvidia-smi
        // dmon), history rings and per-core rows — the 45s lease
        // either tab keeps does NOT flip it. Gating on the metrics
        // identity makes the grant self-heal a bridge re-attach
        // (new object → reload → re-grant); Component.onDestruction
        // on the tab root releases it on every unload path.
        Loader {
            id: clusterLoader
            Layout.fillWidth: true
            Layout.fillHeight: true   // fit the viewport — pane's [E] flexes; no scroll
            active: root.shown && root.m !== null
            sourceComponent: Components.CoreSystemPane { anchors.fill: parent }
            onLoaded: if (root.m) root.m.coreVisible = true
            onActiveChanged: if (!active && root.m) root.m.coreVisible = false
        }
    }

    Component.onDestruction: if (root.m) root.m.coreVisible = false
}
