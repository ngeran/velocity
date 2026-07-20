// =============================================================================
// settings/config/SharedState.qml
// Unified Global State Orchestrator (zero-regression restoration)
// =============================================================================

pragma Singleton
import QtQuick

QtObject {
    id: stateEngine

    // =========================================================================
    // THEME STATE TRACKING FIELDS
    // =========================================================================
    // --- THEME STATE — bound live to the canonical ThemeConfig singleton ---
    // Same-module singleton (settings/config/qmldir), so no import is needed.
    // These are reactive bindings: any ThemeService mutation of ThemeConfig
    // propagates here instantly, and on to ThemeInfoCard. updateTheme() below
    // is deprecated (kept as a no-op so its caller does not error).
    property string themeName:           ThemeConfig.metadata.name
    property string themeAuthor:         getThemeAuthor()
    property bool   themeIsOLED:         ThemeConfig.metadata.oledClamp
    property color  themePrimaryColor:   ThemeConfig.colors.primary
    property color  themeSecondaryColor: ThemeConfig.colors.secondary
    property color  themeTextColor:      ThemeConfig.colors.text

    // =========================================================================
    // WALLPAPER STATE & METRICS PIPELINE
    // =========================================================================
    property string wallpaperPath:       ""
    property string wallpaperName:       "None"

    // Restored fields to prevent WallpaperInfoCard.qml degradation:
    property bool   wallpaperCyclingEnabled:  false
    property int    wallpaperCycleInterval:   900
    property int    wallpaperCountdown:       900
    property string wallpaperTransitionType:  "simple"
    property int    wallpaperCount:           0

    // =========================================================================
    // SYSTEM RESOURCE TRACKING
    // =========================================================================
    property string cpuUsage:            "0%"
    property string memUsage:            "0%"
    property string gpuUsage:            "0%"
    property string diskUsage:           "0%"

    // =========================================================================
    // DASHBOARD VISIBILITY — gate for background-service poll timers
    // =========================================================================
    // Set by shell.qml onShownChanged. Control services bind their poll
    // Timer.running to this so they stop forking when the dashboard is closed.
    // CoreEngine/Gpu/Thermal stay always-on (they feed the deepcool-py LCD).
    property bool   dashboardVisible:        false

    // =========================================================================
    // MUTATION HANDLERS
    // =========================================================================

    // Theme properties are now reactive bindings into ThemeConfig (the
    // single source of truth). The deprecated updateTheme() no-op function
    // was removed in Phase 0 cleanup — no call sites existed.

    function updateWallpaper(path) {
        console.log("[SharedState] updateWallpaper called with path:", path)
        stateEngine.wallpaperPath = path !== undefined ? path : ""
        stateEngine.wallpaperName = basename(stateEngine.wallpaperPath)
        console.log("[SharedState] wallpaperPath set to:", stateEngine.wallpaperPath)
    }

    function updateResources(cpu, mem, gpu, disk) {
        stateEngine.cpuUsage  = cpu  !== undefined ? cpu  : "0%"
        stateEngine.memUsage  = mem  !== undefined ? mem  : "0%"
        stateEngine.gpuUsage  = gpu  !== undefined ? gpu  : "0%"
        stateEngine.diskUsage = disk !== undefined ? disk : "0%"
    }

    function basename(path) {
        if (!path || path === "") return "None"
        let parts = path.split('/')
        return parts[parts.length - 1]
    }

    function getThemeAuthor() {
        // Derive theme author from the source metadata
        var source = ThemeConfig.metadata.source || "unknown"
        switch (source) {
            case "preset":
                return "QuickShell Preset"
            case "matugen":
                return "Matugen (wallpaper)"
            case "stylix":
                return "Stylix (seed)"
            case "manual":
                return "Custom (manual)"
            case "custom":
                return "Saved palette"
            default:
                return source.charAt(0).toUpperCase() + source.slice(1)
        }
    }
}
