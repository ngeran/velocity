// =============================================================================
// DashboardOverviewTab.qml — Rebuilt tab-0 with bento grid
// =============================================================================
//
// This is the new overviewTab (tab 0) for ModernDashboard.
// Replaces the old complex layout with a clean bento grid:
// - Row 1: ClockWidget · ThemeQuickSwitch · IdentityWidget · ResourcesWidget
// - Row 2: CalendarWidget · NetworkWidget · PowerCard
//
// All wrapped in DashboardCard containers for theme-reactive glass cards.
//
// =============================================================================

import "." as Components
import QtQuick
import QtQuick.Layouts
import "../config" as Config

Item {
    id: root
    visible: parent.currentTab === 0
    anchors.fill: parent

    // Top margin for content area
    property real cardMargin: 16
    property real cardSpacing: 16
    property real rowSpacing: 16

    // Row heights
    property real row1Height: parent.height * 0.52
    property real row2Height: parent.height * 0.44

    // =========================================================================
    // ROW 1 — Clock, Theme, Identity, Resources
    // =========================================================================
    Row {
        id: row1
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: cardMargin
        }
        height: row1Height
        spacing: cardSpacing

        // ── CLOCK WIDGET (30% width) ───────────────────────────────────────
        Components.DashboardCard {
            width: parent.width * 0.30
            height: parent.height

            Components.ClockWidget {
                anchors.fill: parent
            }
        }

        // ── THEME QUICK-SWITCH (22% width) ────────────────────────────────────
        Components.DashboardCard {
            width: parent.width * 0.22
            height: parent.height

            Components.ThemeQuickSwitch {
                anchors.fill: parent
            }
        }

        // ── IDENTITY WIDGET (24% width) ────────────────────────────────────────
        Components.DashboardCard {
            width: parent.width * 0.24
            height: parent.height

            Components.IdentityWidget {
                anchors.fill: parent
            }
        }

        // ── RESOURCES WIDGET (24% width - right column) ───────────────────────
        Components.DashboardCard {
            width: parent.width * 0.24
            height: parent.height

            Components.ResourcesWidget {
                anchors.fill: parent
            }
        }
    }

    // =========================================================================
    // ROW 2 — Calendar, Network, Power
    // =========================================================================
    Row {
        id: row2
        anchors {
            left: parent.left
            right: parent.right
            margins: cardMargin
        }
        anchors.top: row1.bottom
        anchors.topMargin: rowSpacing
        height: row2Height
        spacing: cardSpacing

        // ── CALENDAR WIDGET (40% width) ────────────────────────────────────────
        Components.DashboardCard {
            width: parent.width * 0.40
            height: parent.height

            Components.CalendarWidget {
                anchors.fill: parent
            }
        }

        // ── NETWORK WIDGET (30% width) ────────────────────────────────────────
        Components.DashboardCard {
            width: parent.width * 0.30
            height: parent.height

            Components.NetworkWidget {
                anchors.fill: parent
            }
        }

        // ── POWER CARD (30% width) ─────────────────────────────────────────────
        Components.DashboardCard {
            width: parent.width * 0.30
            height: parent.height

            Components.PowerCard {
                anchors.fill: parent
            }
        }
    }
}
