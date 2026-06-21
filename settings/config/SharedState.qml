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
    property string themeAuthor:         "QuickShell"
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
    // MUTATION HANDLERS
    // =========================================================================

    // DEPRECATED — intentional no-op. The theme* properties above are now
    // reactive bindings into ThemeConfig (the single source of truth), so
    // manual mirroring is neither needed nor permitted — assigning here
    // would break those bindings. The signature is retained only so the
    // existing call site in ThemeModule.qml does not error.
    function updateTheme(name, author, isOLED, primary, secondary, text) { }

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
}
