// =============================================================================
// SettingsConfigService.qml — Settings Configuration Persistence Service
// =============================================================================
//
// Manages persistent settings for the Obsidian Core shell.
// Stores settings in ~/.config/quickshell/settings-config.json
// Handles both settings-process and cross-process settings (bar, etc.)
//
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
import Quickshell.Io
import "../config" as Config

Item {
    id: root

    // =========================================================================
    // SETTINGS STATE
    // =========================================================================

    // Appearance settings (settings-process only) — pushed live to Config.SettingsConfig
    property string animationSpeed: "normal"  // fast, normal, slow
    property int cornerRadius: 0               // 0, 4, 8, 12
    onAnimationSpeedChanged: applyAppearance()
    onCornerRadiusChanged: applyAppearance()

    // Map the user's Animation Speed + Corner Radius into the live design tokens
    // consumed across the dashboard (SettingsConfig.qml). Called on change and on
    // load (applyLoadedSettings re-sets the props, firing the handlers above).
    function applyAppearance() {
        var m = root.animationSpeed === "fast" ? 0.5 : (root.animationSpeed === "slow" ? 1.7 : 1.0)
        Config.SettingsConfig.animMultiplier = m
        Config.SettingsConfig.cornerRadius = root.cornerRadius
    }

    // Bar settings (cross-process - bar reads from config file)
    property int barHeight: 26                  // 20, 26, 32, 40
    property int workspaceCount: 5             // 3, 5, 7, 9

    // Clock settings (cross-process - bar reads from config file)
    property string clockCity: "Local"          // Display name for timezone
    property int clockOffset: 0                 // UTC offset in hours (-12 to +14)

    // Wallpaper settings
    property bool syncThemeToWallpaper: false      // Auto-regenerate theme when wallpaper changes (legacy; now maps to rebuildOnWallpaperChange)
    property bool rebuildOnWallpaperChange: false   // Trigger Stylix rebuild when wallpaper changes (requires pkexec)

    // Pulses true briefly after every saveSettings() — drives the Settings-tab "✓ APPLIED" toast.
    property bool justSaved: false
    Timer { id: _justSavedReset; interval: 1200; onTriggered: root.justSaved = false }

    // =========================================================================
    // CONFIG PERSISTENCE
    // =========================================================================

    property string configFilePath: StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString()
                                       .replace("file://", "") + "/quickshell/settings-config.json"

    // Process for saving config
    property Process saveProcess: Process {
        command: []
        running: false

        onExited: function(exitCode) {
            if (exitCode === 0) {
                console.log("[SettingsConfigService] Config saved successfully")
            } else {
                console.log("[SettingsConfigService] Failed to save config, exit code:", exitCode)
            }
        }
    }

    // Process for loading config
    property Process loadProcess: Process {
        command: []
        running: false

        property string buffer: ""

        stdout: SplitParser {
            onRead: function(data) {
                loadProcess.buffer += data
            }
        }

        onRunningChanged: {
            if (!running && loadProcess.buffer.length > 0) {
                try {
                    var data = JSON.parse(loadProcess.buffer)
                    console.log("[SettingsConfigService] Config loaded:", JSON.stringify(data))
                    applyLoadedSettings(data)
                } catch (e) {
                    console.log("[SettingsConfigService] Failed to parse config:", e)
                    // Use defaults if config is corrupt
                }
                loadProcess.buffer = ""
            }
        }
    }

    // =========================================================================
    // PUBLIC API
    // =========================================================================

    function saveSettings() {
        var config = {
            animationSpeed: root.animationSpeed,
            cornerRadius: root.cornerRadius,
            barHeight: root.barHeight,
            workspaceCount: root.workspaceCount,
            clockCity: root.clockCity,
            clockOffset: root.clockOffset,
            syncThemeToWallpaper: root.syncThemeToWallpaper,
            rebuildOnWallpaperChange: root.rebuildOnWallpaperChange
        }

        var json = JSON.stringify(config, null, 2)
        saveProcess.command = ["sh", "-c", "mkdir -p ~/.config/quickshell && printf '%s' '" + json.replace(/'/g, "'\\''") + "' > '" + root.configFilePath + "'"]
        saveProcess.running = true

        // Also write bar-specific config for cross-process sync
        saveBarConfig()

        // Pulse the "✓ APPLIED" toast in the Settings tab
        root.justSaved = true
        _justSavedReset.restart()
    }

    // One-click escape hatch for the Settings tab
    function resetToDefaults() {
        root.animationSpeed = "normal"
        root.cornerRadius = 0
        root.barHeight = 26
        root.workspaceCount = 5
        root.clockCity = "Local"
        root.clockOffset = 0
        root.syncThemeToWallpaper = false
        root.rebuildOnWallpaperChange = false
        root.saveSettings()   // persists + pushes appearance tokens + pulses the toast
    }

    function loadSettings() {
        console.log("[SettingsConfigService] Loading settings from:", root.configFilePath)
        loadProcess.command = ["cat", root.configFilePath]
        loadProcess.running = true
    }

    // =========================================================================
    // INTERNAL
    // =========================================================================

    function applyLoadedSettings(data) {
        if (data.animationSpeed !== undefined && ["fast", "normal", "slow"].indexOf(data.animationSpeed) !== -1) {
            root.animationSpeed = data.animationSpeed
        }
        if (data.cornerRadius !== undefined && [0, 4, 8, 12].indexOf(data.cornerRadius) !== -1) {
            root.cornerRadius = data.cornerRadius
        }
        if (data.barHeight !== undefined && [20, 26, 32, 40].indexOf(data.barHeight) !== -1) {
            root.barHeight = data.barHeight
        }
        if (data.workspaceCount !== undefined && [3, 5, 7, 9].indexOf(data.workspaceCount) !== -1) {
            root.workspaceCount = data.workspaceCount
        }
        if (data.clockCity !== undefined) {
            root.clockCity = data.clockCity
        }
        if (data.clockOffset !== undefined && data.clockOffset >= -12 && data.clockOffset <= 14) {
            root.clockOffset = data.clockOffset
        }
        if (data.syncThemeToWallpaper !== undefined) {
            root.syncThemeToWallpaper = data.syncThemeToWallpaper
        }
        if (data.rebuildOnWallpaperChange !== undefined) {
            root.rebuildOnWallpaperChange = data.rebuildOnWallpaperChange
        }
    }

    function saveBarConfig() {
        // Write bar-specific config for bar process to read
        var barConfig = {
            barHeight: root.barHeight,
            workspaceCount: root.workspaceCount,
            clockCity: root.clockCity,
            clockOffset: root.clockOffset
        }
        var json = JSON.stringify(barConfig, null, 2)
        var barConfigPath = StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString().replace("file://", "") + "/quickshell/bar-config.json"
        var barWriter = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
        barWriter.command = ["sh", "-c", "printf '%s' '" + json.replace(/'/g, "'\\''") + "' > " + barConfigPath]
        barWriter.running = true
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    Component.onCompleted: {
        loadSettings()
    }
}
