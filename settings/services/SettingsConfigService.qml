// =============================================================================
// SettingsConfigService.qml — Settings Configuration Persistence Service
// =============================================================================
//
// Manages persistent settings for the Obsidian Core shell.
// Settings-app keys: ~/.config/quickshell/settings-config.json
// Bar keys: bar-config.json only (the file the bar process reads)
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

    // Map the user's Corner Radius into the live design token consumed across
    // the dashboard (SettingsConfig.qml). Called on change and on load
    // (applyLoadedSettings re-sets the prop, firing the handler above).
    // Animation durations: Config.MotionConfig intakes animationSpeed from
    // settings-config.json itself (C1c) — no push needed here.
    function applyAppearance() {
        Config.SettingsConfig.cornerRadius = root.cornerRadius
    }

    // Bar settings (cross-process - bar reads from config file)
    property int barHeight: 26                  // any int 18–64 (mirrors bar-config.json)
    // Bar style (bar/styles/<name>/Scene.qml) — live-swappable; the bar
    // falls back to "vector" when a style is missing/broken.
    property string barStyle: "vector"
    // Island style QD-OLED guard (bar-config.json islandBurnGuard).
    property bool islandBurnGuard: true
    // Strip styles' QD-OLED orbit guard (bar-config.json stripBurnGuard) —
    // vector/notch/ryoku ride the shared BurnOrbit tick.
    property bool stripBurnGuard: true
    // Bar edge (UA 2.6 stage 1): "top" | "bottom" — mirrors bar-config.json;
    // the bar flips scenes/popovers live via BarConfig's ingest.
    property string barPosition: "top"
    // OSD track style (J5): "bar" = continuous fill, "segments" = segment
    // track — mirrors bar-config.json; the bar's Osd/island read it live.
    property string osdStyle: "bar"
    property int workspaceCount: 5             // 3, 5, 7, 9

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
                loadProcess.buffer += data + "\n"
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
        // Bar keys live only in bar-config.json (saveBarConfig).
        var config = {
            schemaVersion: 2,
            animationSpeed: root.animationSpeed,
            cornerRadius: root.cornerRadius,
            matugenOnWallpaperChange: root.matugenOnWallpaperChange
        }

        var json = JSON.stringify(config, null, 2)
        // Single write funnel for the whole settings process (atomic tmp+mv —
        // readers never see a half-written file; rename-compat verified in bar).
        ThemeService._atomicWrite(root.configFilePath, json, function(ok) {
            if (ok) Config.MotionConfig.reloadFromDisk()
        })

        // (Bar keys no longer sync here — P2.5: bar-config.json's writer is
        // the bar's BarConfigWriter; bar-shaped picks flow through it at the
        // moment they are made, not on settings-config saves.)

        // Pulse the "✓ APPLIED" toast in the Settings tab
        root.justSaved = true
        _justSavedReset.restart()
    }

    // One-click escape hatch for the Settings tab. Resets the WHOLE saved
    // surface (P1.7: barStyle/osdStyle/both burn guards were silently kept).
    function resetToDefaults() {
        root.animationSpeed = "normal"
        root.cornerRadius = 0
        root.barHeight = 26
        root.barPosition = "top"
        root.workspaceCount = 5
        root.barStyle = "vector"
        root.osdStyle = "bar"
        root.islandBurnGuard = true
        root.stripBurnGuard = true
        root.matugenOnWallpaperChange = false
        root.saveSettings()   // persists + pushes appearance tokens + pulses the toast
        root.saveBarConfig()  // the bar keys above live in bar-config.json (P2.5)
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
        // Migrate the legacy `rebuildOnWallpaperChange` key → matugenOnWallpaperChange.
        if (data.matugenOnWallpaperChange !== undefined) {
            root.matugenOnWallpaperChange = data.matugenOnWallpaperChange
        } else if (data.rebuildOnWallpaperChange !== undefined) {
            root.matugenOnWallpaperChange = data.rebuildOnWallpaperChange
        }
    }

    function applyBarConfig(data) {
        if (data.barHeight !== undefined)
            root.barHeight = Math.max(18, Math.min(64, Math.round(data.barHeight)))
        if (typeof data.barStyle === "string" && data.barStyle.length > 0)
            root.barStyle = data.barStyle
        if (data.barPosition === "top" || data.barPosition === "bottom")
            root.barPosition = data.barPosition
        if (data.osdStyle === "bar" || data.osdStyle === "segments")
            root.osdStyle = data.osdStyle
        if ([3, 5, 7, 9].indexOf(data.workspaceCount) !== -1)
            root.workspaceCount = data.workspaceCount
        if (typeof data.islandBurnGuard === "boolean")
            root.islandBurnGuard = data.islandBurnGuard
        if (typeof data.stripBurnGuard === "boolean")
            root.stripBurnGuard = data.stripBurnGuard
    }

    function saveBarConfig() {
        // P2.5: the bar's BarConfigWriter (via HostBridge) is bar-config.json's
        // single writer — read-modify-write over the disk content, so bar-owned
        // keys this mirror doesn't model survive; BarConfig reloads in-process.
        // All 8 modeled keys are merged together so callers that changed only
        // the mirror still persist the whole known surface.
        var w = HostBridge.configWriter
        if (!w) { console.log("[SettingsConfigService] bar config writer not ready"); return }
        w.merge({
            barHeight: root.barHeight,
            workspaceCount: root.workspaceCount,
            barStyle: root.barStyle,
            barPosition: root.barPosition,
            osdStyle: root.osdStyle,
            islandBurnGuard: root.islandBurnGuard,
            stripBurnGuard: root.stripBurnGuard
        })
    }

    // ── bar-config mirror read (read-only since P2.5) ────────────────────────
    // The mirror (barHeight/barStyle/…) only feeds the settings window's own
    // reads (slide-in offset). Writes go through the bar's BarConfigWriter —
    // including BarSettingsBody's direct picks, which bypass this
    // mirror entirely — so the mirror just follows the file (watchChanges).
    FileView {
        path: StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString().replace("file://", "") + "/quickshell/bar-config.json"
        watchChanges: true
        printErrors: false
        onTextChanged: {
            try {
                var data = JSON.parse(text())
                if (data) root.applyBarConfig(data)
            } catch (e) { /* keep mirror defaults */ }
        }
        Component.onCompleted: reload()
    }

    // (Bar style discovery lived here for the Settings ▸ Bar pane's pick
    // cards; the pane was consolidated away — the bar's overlay scans the
    // styles itself and writes directly since P2.5.)

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    Component.onCompleted: {
        loadSettings()
    }
}
