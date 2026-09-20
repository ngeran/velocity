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
    // Bar style (bar/styles/<name>/Scene.qml) — live-swappable; the bar
    // falls back to "vector" when a style is missing/broken.
    property string barStyle: "vector"
    property var barStyles: ["vector"]          // scanned from bar/styles/
    property int workspaceCount: 5             // 3, 5, 7, 9

    // Clock settings (cross-process - bar reads from config file)
    property string clockCity: "Local"          // Display name for timezone
    property int clockOffset: 0                 // UTC offset in hours (-12 to +14)

    // Auto-regenerate the palette from the active wallpaper via matugen
    // whenever it changes (instant, no rebuild). Default OFF: a burn-in
    // wallpaper cycler would otherwise clobber the user's custom theme on every
    // rotation. Toggle on in the Wallpaper tab. On-demand extract (no auto
    // apply) lives in the Theme tab manual editor — the FROM WALLPAPER button.
    property bool matugenOnWallpaperChange: false

    // Pulses true briefly after every saveSettings() — drives the Settings-tab "✓ APPLIED" toast.
    property bool justSaved: false
    Timer { id: _justSavedReset; interval: 1200; onTriggered: root.justSaved = false }

    // =========================================================================
    // CONFIG PERSISTENCE
    // =========================================================================

    property string configFilePath: StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString()
                                       .replace("file://", "") + "/quickshell/settings-config.json"

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
            schemaVersion: 1,   // bump + branch in applyLoadedSettings on shape changes
            animationSpeed: root.animationSpeed,
            cornerRadius: root.cornerRadius,
            barHeight: root.barHeight,
            workspaceCount: root.workspaceCount,
            clockCity: root.clockCity,
            clockOffset: root.clockOffset,
            matugenOnWallpaperChange: root.matugenOnWallpaperChange
        }

        var json = JSON.stringify(config, null, 2)
        // Single write funnel for the whole settings process (atomic tmp+mv —
        // readers never see a half-written file; rename-compat verified in bar).
        ThemeService._atomicWrite(root.configFilePath, json)

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
        root.matugenOnWallpaperChange = false
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
        if (typeof data.barStyle === "string" && data.barStyle.length > 0) {
            root.barStyle = data.barStyle
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
        // Migrate the legacy `rebuildOnWallpaperChange` key → matugenOnWallpaperChange.
        if (data.matugenOnWallpaperChange !== undefined) {
            root.matugenOnWallpaperChange = data.matugenOnWallpaperChange
        } else if (data.rebuildOnWallpaperChange !== undefined) {
            root.matugenOnWallpaperChange = data.rebuildOnWallpaperChange
        }
    }

    function saveBarConfig() {
        // Write bar-specific config for bar process to read
        var barConfig = {
            schemaVersion: 1,   // bar's ingestConfigText ignores unknown keys; bump on shape changes
            barHeight: root.barHeight,
            workspaceCount: root.workspaceCount,
            clockCity: root.clockCity,
            clockOffset: root.clockOffset,
            barStyle: root.barStyle
        }
        var json = JSON.stringify(barConfig, null, 2)
        var barConfigPath = StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString().replace("file://", "") + "/quickshell/bar-config.json"
        ThemeService._atomicWrite(barConfigPath, json)
    }

    // ── bar style discovery ────────────────────────────────────────────────
    // A style = a folder under ~/.config/quickshell/bar/styles/ with a
    // Scene.qml. Scanned at service init and on every BAR STYLE pick (new
    // style folders appear without restarting the settings shell).
    function scanBarStyles() {
        styleScanProc.running = true
    }

    Process {
        id: styleScanProc
        command: ["sh", "-c",
            "ls -1d '" + StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString().replace("file://", "") + "/quickshell/bar/styles/'*/Scene.qml 2>/dev/null | sed 's|.*/styles/||; s|/Scene.qml||' | sort"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { styleScanProc.buffer += data } }
        onStarted: buffer = ""
        onExited: {
            var lines = styleScanProc.buffer.trim().split("\n").filter(function(l) { return l.length > 0 })
            styleScanProc.buffer = ""
            if (lines.length > 0) root.barStyles = lines
        }
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    Component.onCompleted: {
        loadSettings()
        scanBarStyles()
    }
}
