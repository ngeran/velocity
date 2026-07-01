// =============================================================================
// DashboardOverviewTab.qml — Explicit Pixel-Perfect Bento Grid
// VERSION: V1.06 — No Column/anchors.fill conflict; pure explicit geometry
//
// ROOT CAUSE (V1.04/V1.05): Using Column{anchors.fill} + Row{height:parent.height}
// creates a circular binding — Column height depends on children, children depend
// on Column height. QML resolves this unpredictably, causing Row 1 to consume
// all available height. Fix: explicit y-placement on an Item, zero parent refs.
// =============================================================================

import "." as Components
import QtQuick
import "../config" as Config

Item {
    id: root
    anchors.fill: parent

    readonly property string layoutVersion: "V1.06"

    // =========================================================================
    // DIMENSION CONSTANTS — all derived from root.width / root.height only
    // =========================================================================
    readonly property real pad:     20          // outer margin on all sides
    readonly property real gap:     14          // gap between rows and between cards

    // Usable canvas
    readonly property real cw: root.width  - pad * 2
    readonly property real ch: root.height - pad * 2

    // Row heights: two rows + one inter-row gap must fill ch exactly
    readonly property real r1h: (ch - gap) * 0.54
    readonly property real r2h: (ch - gap) * 0.46

    // Per-row available widths (innerWidth minus inter-card gaps)
    // Row 1: 4 cards → 3 gaps
    readonly property real r1w: cw - gap * 3
    // Row 2: 3 cards → 2 gaps
    readonly property real r2w: cw - gap * 1

    // Y origins (no Column involved — pure coordinate math)
    readonly property real row1Y: pad
    readonly property real row2Y: pad + r1h + gap

    // =========================================================================
    // ROW 1 — Clock | ThemeSwitch | Identity | Resources
    // =========================================================================
    Row {
        x: root.pad
        y: root.row1Y
        width: root.cw
        height: root.r1h
        spacing: root.gap

        Components.DashboardCard {
            width: root.r1w * 0.29
            height: root.r1h
            Components.ClockWidget { anchors.fill: parent }
        }

        Components.DashboardCard {
            width: root.r1w * 0.21
            height: root.r1h
            Components.ThemeQuickSwitch { anchors.fill: parent }
        }

        Components.DashboardCard {
            width: root.r1w * 0.25
            height: root.r1h
            Components.IdentityWidget { anchors.fill: parent }
        }

        Components.DashboardCard {
            width: root.r1w * 0.25
            height: root.r1h
            Components.ResourcesWidget { anchors.fill: parent }
        }
    }

    // =========================================================================
    // ROW 2 — Calendar | Network
    // =========================================================================
    Row {
        x: root.pad
        y: root.row2Y
        width: root.cw
        height: root.r2h
        spacing: root.gap

        Components.DashboardCard {
            width: root.r2w * 0.58
            height: root.r2h
            Components.CalendarWidget { anchors.fill: parent }
        }

        Components.DashboardCard {
            width: root.r2w * 0.42
            height: root.r2h
            Components.NetworkWidget { anchors.fill: parent }
        }
    }
}
