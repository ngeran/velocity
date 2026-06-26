// =============================================================================
// BarConfig.qml — Design tokens and configuration
// =============================================================================
//
// This singleton contains all visual design tokens for the bar.
// Colors are dynamically sourced from ThemeConfig for theme switching.
//
// SIZES
//   barHeight - Total bar height in pixels
//   iconSize - Size of each icon square
//   iconSpacing - Space between icons
//
// BEHAVIOR
//   workspaceCount - Number of workspace dots to display
//   *_interval - Polling intervals for services (milliseconds)
// =============================================================================

pragma Singleton

import QtQuick

QtObject {
    // =========================================================================
    // GEOMETRY
    // =========================================================================

    readonly property int barHeight: 26
    readonly property int barPadding: 12
    readonly property int iconSize: 32  // Increased from 20 for better clickability
    readonly property int iconSpacing: 4

    // =========================================================================
    // COLOURS (Dynamic from ThemeConfig)
    // =========================================================================

    readonly property color colorBackground: ThemeConfig.colors.background
    readonly property color colorAccent: ThemeConfig.colors.secondary
    readonly property color colorText: ThemeConfig.colors.text
    readonly property color colorTextDim: ThemeConfig.colors.textDim
    readonly property color colorMuted: ThemeConfig.colors.error
    readonly property color colorBorder: ThemeConfig.colors.border

    // =========================================================================
    // TYPOGRAPHY
    // =========================================================================

    readonly property string fontFamily: "monospace"
    readonly property string fontNerd: "JetBrainsMono Nerd Font"
    readonly property int fontSizeClock: 14
    readonly property int fontSizeIcon: 14

    // =========================================================================
    // WORKSPACES
    // =========================================================================

    readonly property int workspaceCount: 5
    readonly property int workspaceDotWidth: 6
    readonly property int workspaceDotWidthActive: 14
    readonly property int workspaceDotHeight: 6

    // =========================================================================
    // POLLING INTERVALS (milliseconds)
    // =========================================================================

    readonly property int networkInterval: 3000
    readonly property int bluetoothInterval: 6000
    readonly property int audioInterval: 3000
    readonly property int workspaceInterval: 1500
}
