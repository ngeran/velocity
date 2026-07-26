// =============================================================================
// DashboardOverviewTab.qml — "TEMPORAL MAP" dashboard
// VERSION: V8.04 — CALENDAR (perfect square) + 2×2 GRID, fills the viewport
//
// LAYOUT (below the shared Header / right of the shared SidebarNav):
//   ┌──────────────┬─────────────────────┐
//   │              │ THEME     │ DISPLAY  │
//   │  TEMPORAL    │ switcher  │  matrix  │
//   │  MAP cal     ├───────────┼──────────┤
//   │  (square)    │ SPECTRAL  │ SYSTEM   │
//   │              │  tokens   │ ref cap  │
//   └──────────────┴─────────────────────┘
//
// The calendar is a PERFECT SQUARE sized to the content height — it fills top-to
// bottom with no void. The 2×2 widget grid takes the remaining width and fills
// the height; each card distributes its content to fill its cell. No empty space.
//
// Every colour reads from Config.ThemeConfig.colors → recolours live with the
// active theme. requestTab(int) bubbles to ModernDashboard (Theme CHANGE → Themes).
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "." as Components
import "../config" as Config

Item {
    id: root
    anchors.fill: parent

    readonly property string layoutVersion: "V8.04"

    // Bubble a tab-switch request up to ModernDashboard.
    signal requestTab(int index)

    // ── Geometry: fill the viewport. The calendar is a PERFECT SQUARE sized to
    //    the content height (so it fills top-to-bottom with no void); the 2×2
    //    grid takes the remaining width and fills the height. ─────────────────
    readonly property real _margin: 16
    readonly property real _gap: 12
    readonly property real _calSide: (root.height > 0 && root.width > 0)
        ? Math.min(root.height - 2 * root._margin,
                   (root.width - 2 * root._margin - root._gap) * 0.55)
        : 0   // 0 until the anchor chain resolves root.height (avoids an init warning)

    // =========================================================================
    // BODY — fills the content area edge to edge (no scrolling, no voids)
    // =========================================================================
    RowLayout {
        anchors.fill: parent
        anchors.margins: root._margin
        spacing: root._gap

        // ── Temporal Map calendar — perfect square, fills the full height ──
        Components.DashboardCard {
            accent: Config.ThemeConfig.colors.primary
            showBrackets: true
            Layout.preferredWidth: root._calSide
            Layout.preferredHeight: root._calSide
            Components.CalendarWidget { anchors.fill: parent }
        }

        // ── 2×2 grid: the rest of the widgets, each filling its cell ──
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            rowSpacing: root._gap
            columnSpacing: root._gap

            Components.ActiveThemeCard {     // Theme Switcher  (top-left)
                Layout.fillWidth: true; Layout.fillHeight: true
                onChangeRequested: root.requestTab(1)   // → Themes tab
            }
            Components.DisplayInfoCard {     // Display Matrix (top-right)
                Layout.fillWidth: true; Layout.fillHeight: true
            }
            Components.ActivePaletteCard {   // Spectral Tokens (bottom-left)
                Layout.fillWidth: true; Layout.fillHeight: true
            }
            Components.ActiveWallpaperCard { // System Reference Capture (bottom-right)
                Layout.fillWidth: true; Layout.fillHeight: true
            }
        }
    }
}
