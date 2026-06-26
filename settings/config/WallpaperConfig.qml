// =============================================================================
// WallpaperConfig.qml — Wallpaper Configuration Constants
// =============================================================================
//
// Configuration values for wallpaper management.
// Follows OLED-minimal aesthetic matching ModernDashboard.qml.
//
// =============================================================================

pragma Singleton
import QtQuick

QtObject {
    // =========================================================================
    // DEFAULT VALUES
    // =========================================================================

    /// Default auto-cycle interval in milliseconds (5 minutes)
    readonly property int defaultCycleInterval: 300000

    /// Default transition type
    readonly property string defaultTransitionType: "outer"

    /// Transition FPS
    readonly property int transitionFps: 60

    /// Transition step (0-255)
    readonly property int transitionStep: 90

    /// Default wallpaper directory
    readonly property string defaultWallpaperDir: ""

    // =========================================================================
    // INTERVAL STEPS (in minutes)
    // =========================================================================

    readonly property var intervalSteps: [1, 2, 5, 10, 15, 30, 60]

    // =========================================================================
    // TRANSITION OPTIONS
    // =========================================================================

    readonly property var transitionOptions: [
        { name: "Outer", value: "outer" },
        { name: "Inner", value: "inner" },
        { name: "Wipe", value: "wipe" },
        { name: "Fade", value: "fade" },
        { name: "Wave", value: "wave" },
        { name: "Any", value: "any" }
    ]

    // =========================================================================
    // UI DIMENSIONS
    // =========================================================================

    // NOTE: Color tokens have been migrated to ThemeConfig to eliminate duplication.
    // WallpaperModule now uses Config.ThemeConfig.colors.* for all theming.
    // behavioral constants below remain.

    /// Section header font size
    readonly property int headerFontSize: 9

    /// Section header letter spacing
    readonly property real headerLetterSpacing: 2.5

    /// Control height (buttons, inputs)
    readonly property int controlHeight: 32

    /// Corner radius (0 for OLED-minimal)
    readonly property int cornerRadius: 0

    /// Border width
    readonly property int borderWidth: 1

    // =========================================================================
    // GRID SETTINGS
    // =========================================================================

    /// Number of columns in wallpaper preview grid
    readonly property int gridColumns: 4

    /// Thumbnail cell width
    readonly property int cellWidth: 192

    /// Thumbnail cell height
    readonly property int cellHeight: 136

    /// Grid spacing
    readonly property int gridSpacing: 8
}
