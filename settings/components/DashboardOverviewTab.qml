// =============================================================================
// DashboardOverviewTab.qml — Tactical left-heavy command layout
// VERSION: V2.01 — Clock+Calendar (left) | CPU+Storage (right top) |
//                 Network+Identity (right bottom). All cards tactical.
//
// Explicit pixel math on an Item root (no Column/anchors.fill circular bindings
// — see V1.04..V1.06 history). Cards are placed by absolute x/y/width/height
// derived only from root.width/root.height. Each card is a tactical DashboardCard
// (showBrackets + accent); colours follow the live theme (multi-accent mapping:
// clock/calendar=warning, processor=secondary, storage=success, network=secondary,
// identity=primary). Reuses the existing Clock/Calendar/Network/Identity widgets
// unchanged; ProcessorArrayWidget + StorageMatrixWidget are new.
// =============================================================================

import "." as Components
import QtQuick
import "../config" as Config

Item {
    id: root
    anchors.fill: parent

    readonly property string layoutVersion: "V2.00"

    // ── geometry (derived from root.width/height only) ──────────────────────
    readonly property real pad: 16          // outer margin
    readonly property real gap: 12          // between cards

    readonly property real cw: root.width  - pad * 2
    readonly property real ch: root.height - pad * 2

    // left column (~32%) + right region
    readonly property real leftW:  Math.round((cw - gap) * 0.32)
    readonly property real rightX: pad + leftW + gap
    readonly property real rightW: cw - leftW - gap

    // left column split: clock 42% / calendar rest
    readonly property real clockH: Math.round((ch - gap) * 0.42)
    readonly property real calY:   pad + clockH + gap
    readonly property real calH:   ch - clockH - gap

    // right top (60%) split: processor 58% / storage rest
    readonly property real topH:   Math.round((ch - gap) * 0.60)
    readonly property real procW:  Math.round((rightW - gap) * 0.58)
    readonly property real storX:  rightX + procW + gap
    readonly property real storW:  rightW - procW - gap

    // right bottom (rest) split: network 62% / identity rest
    readonly property real botY:   pad + topH + gap
    readonly property real botH:   ch - topH - gap
    readonly property real netW:   Math.round((rightW - gap) * 0.62)
    readonly property real idX:    rightX + netW + gap
    readonly property real idW:    rightW - netW - gap

    // ── LEFT: System Clock ──────────────────────────────────────────────────
    Components.DashboardCard {
        x: root.pad; y: root.pad; width: root.leftW; height: root.clockH
        accent: Config.ThemeConfig.colors.warning; showBrackets: true
        Components.ClockWidget { anchors.fill: parent }
    }

    // ── LEFT: Calendar ──────────────────────────────────────────────────────
    Components.DashboardCard {
        x: root.pad; y: root.calY; width: root.leftW; height: root.calH
        accent: Config.ThemeConfig.colors.warning; showBrackets: true
        Components.CalendarWidget { anchors.fill: parent }
    }

    // ── RIGHT TOP: CPU info ─────────────────────────────────────────────────
    Components.DashboardCard {
        x: root.rightX; y: root.pad; width: root.procW; height: root.topH
        accent: Config.ThemeConfig.colors.secondary; showBrackets: true
        Components.CpuInfoWidget { anchors.fill: parent }
    }

    // ── RIGHT TOP: Storage Matrix ───────────────────────────────────────────
    Components.DashboardCard {
        x: root.storX; y: root.pad; width: root.storW; height: root.topH
        accent: Config.ThemeConfig.colors.success; showBrackets: true
        Components.StorageMatrixWidget { anchors.fill: parent }
    }

    // ── RIGHT BOTTOM: Network ───────────────────────────────────────────────
    Components.DashboardCard {
        x: root.rightX; y: root.botY; width: root.netW; height: root.botH
        accent: Config.ThemeConfig.colors.secondary; showBrackets: true
        Components.NetworkWidget { anchors.fill: parent }
    }

    // ── RIGHT BOTTOM: Identity ──────────────────────────────────────────────
    Components.DashboardCard {
        x: root.idX; y: root.botY; width: root.idW; height: root.botH
        accent: Config.ThemeConfig.colors.primary; showBrackets: true
        Components.IdentityWidget { anchors.fill: parent }
    }
}
