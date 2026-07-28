// =============================================================================
// DashboardOverviewTab.qml — "TEMPORAL MAP" dashboard
// VERSION: V8.10 — [Calendar (square) + Weather] | 2×2 identity grid (anchored)
//
// The panel clamps to 720×480 on small screens (content area ≈ 656×408), so the
// calendar column is pinned (min == max) and the 2×2 grid fills the remainder
// with Layout.minimumWidth: 0 on every card + clip:true on the grid. That makes
// the total width always equal the inner width — content can never spill past
// the window edge, and card text elides instead of overflowing.
//
// LAYOUT (below the shared Header / right of the shared SidebarNav):
//   ┌────────────┬──────────────────────────┐
//   │ TEMPORAL   │  ACTIVE       │ ACTIVE   │
//   │   MAP      │  WALLPAPER    │  THEME   │
//   ├────────────┼───────────────┼──────────┤
//   │  WEATHER   │  ACTIVE       │ DISPLAY  │
//   │            │  PALETTE      │  INFO    │
//   └────────────┴───────────────┴──────────┘
//
// Left column: Calendar (top, perfect square) + Weather (fills the space under
// it). Right: a 2×2 grid of identity widgets — Active Wallpaper, Active Theme,
// Active Palette, Display Info. All fill their cells (no empty space).
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

    readonly property string layoutVersion: "V8.09"

    // Bubble a tab-switch request up to ModernDashboard.
    signal requestTab(int index)

    // ── Geometry ────────────────────────────────────────────────────────────
    // The panel clamps to 720×480 on small screens → the content area is only
    // ~656×408. At that width [calendar column] + [2×2 grid] is a tight fit, so
    // BOTH columns are sized explicitly (left + gap + grid == innerW) and the
    // grid clips — content can never spill past the window edge. HudCard adds
    // 16px padding per side, so a ~200px cell has only ~168px of content room;
    // the cards therefore elide/shrink their text.
    readonly property real _margin: 16
    readonly property real _gap: 12
    readonly property real _innerW: Math.max(0, root.width  - 2 * root._margin)
    readonly property real _innerH: Math.max(0, root.height - 2 * root._margin)
    // The calendar is a perfect SQUARE — width == height == _calSide — sized to
    // ~62% of the column height (a proportion the user liked). The left column
    // is exactly _calSide wide so the square calendar fills it (no gap); weather
    // fills the strip beneath; the 2×2 grid is anchored to the right and takes
    // all remaining width. Both sides are ANCHORED (not RowLayout-negotiated) so
    // the widths are exact and can't collapse during the init layout pass.
    readonly property real _calSide: (root.height > 0)
        ? Math.round(root._innerH * 0.62) : 240

    // =========================================================================
    // BODY — [Calendar + Weather] (left half) | 2×2 identity grid (right half)
    // Anchored (not RowLayout) so each half is an exact, deterministic width:
    // left column = _leftW, grid = the remainder. No min/max negotiation → the
    // init-time collapse that RowLayout kept hitting can't happen here.
    // =========================================================================

    // ── Left half: Calendar (top) + Weather (fills below) ──
    ColumnLayout {
        id: leftCol
        anchors.left: parent.left;     anchors.leftMargin: root._margin
        anchors.top: parent.top;       anchors.topMargin: root._margin
        anchors.bottom: parent.bottom; anchors.bottomMargin: root._margin
        width: root._calSide
        spacing: root._gap

        Components.DashboardCard {
            accent: Config.ThemeConfig.colors.primary
            showBrackets: true
            Layout.fillWidth: true
            Layout.preferredHeight: root._calSide   // square: width == height
            Components.CalendarWidget { anchors.fill: parent }
        }

        Components.WeatherCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    // ── Right half: 2×2 identity grid (anchored right of the calendar column) ──
    GridLayout {
        id: identityGrid
        anchors.left: leftCol.right;   anchors.leftMargin: root._gap
        anchors.right: parent.right;   anchors.rightMargin: root._margin
        anchors.top: parent.top;       anchors.topMargin: root._margin
        anchors.bottom: parent.bottom; anchors.bottomMargin: root._margin
        columns: 2
        rowSpacing: root._gap
        columnSpacing: root._gap
        clip: true   // hard guarantee: nothing escapes the window edge

        Components.ActiveWallpaperCard {   // Active Wallpaper (top-left)
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumWidth: 0
        }
        Components.DisplayInfoCard {       // Display Matrix (top-right)
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumWidth: 0
        }
        Components.ActivePaletteCard {     // Active Palette (bottom-left)
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumWidth: 0
        }
        Components.ActiveThemeCard {       // Active Theme (bottom-right)
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumWidth: 0
            onChangeRequested: root.requestTab(1)   // → Themes tab
        }
    }
}
