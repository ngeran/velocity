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
    // Bar edge (UA 2.6 stage 1): "top" | "bottom" — mirrors bar-config.json;
    // the bar flips scenes/popovers live via BarConfig's ingest.
    property string barPosition: "top"
    property var barStyles: ["vector"]          // scanned from bar/styles/
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
        root.barPosition = "top"
        root.workspaceCount = 5
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
        if ([3, 5, 7, 9].indexOf(data.workspaceCount) !== -1)
            root.workspaceCount = data.workspaceCount
        if (typeof data.islandBurnGuard === "boolean")
            root.islandBurnGuard = data.islandBurnGuard
    }

    function saveBarConfig() {
        // Anti-drift: the extras snapshot is captured at startup; a hand-edit
        // made since (motionScale via CLI, …) would be clobbered by writing
        // from that stale snapshot. Re-read the file first and chain the
        // write off the read's exit (skipping applyBarConfig — see the
        // _barConfigReadForSave branch). A read still in flight can't be
        // re-triggered, so write with what we have rather than drop the save.
        if (barConfigRead.running) { _writeBarConfig(); return }
        root._barConfigReadForSave = true
        barConfigRead.running = true
    }

    function _writeBarConfig() {
        var barConfig = {
            schemaVersion: 1,   // bar's ingestConfigText ignores unknown keys; bump on shape changes
            barHeight: root.barHeight,
            workspaceCount: root.workspaceCount,
            barStyle: root.barStyle,
            barPosition: root.barPosition,
            islandBurnGuard: root.islandBurnGuard
        }
        // Merge back bar-owned keys this service does not model (motionScale,
        // reduceMotion, …) so a save doesn't reset them.
        for (var k in root.barConfigExtras) {
            if (Object.prototype.hasOwnProperty.call(root.barConfigExtras, k))
                barConfig[k] = root.barConfigExtras[k]
        }
        var json = JSON.stringify(barConfig, null, 2)
        var barConfigPath = StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString().replace("file://", "") + "/quickshell/bar-config.json"
        ThemeService._atomicWrite(barConfigPath, json, function(ok) {
            if (!ok) return
            ThemeService._runSh("n=0; until quickshell ipc -c bar call config reload 2>&1 | grep -q ok; do " +
                                "n=$((n+1)); [ $n -ge 10 ] && exit 1; sleep 0.15; done", "bar config nudge")
        })
    }

    // ── bar-config extras capture ───────────────────────────────────────────
    // Everything in bar-config.json the service does NOT model, so saves can
    // merge it back instead of clobbering it. Snapshot is refreshed from disk
    // at the START of every save (see saveBarConfig) — the startup snapshot
    // alone would clobber hand-edits made since (motionScale via CLI etc.).
    property var barConfigExtras: ({})
    property bool _barConfigReadForSave: false
    property var barConfigRead: Process {   // unbounded-ok: waived — see service header
        command: ["cat", StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString().replace("file://", "") + "/quickshell/bar-config.json"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { barConfigRead.buffer += data + "\n" } }
        onStarted: buffer = ""
        onExited: {
            if (running === false && barConfigRead.buffer.trim().length > 0) {
                try {
                    var data = JSON.parse(barConfigRead.buffer)
                    // Dropped on save: rightLayout (now plugins-state.json layout) and
                    // clockCity/clockOffset (now the nikos.clock plugin's `zone` setting).
                    var dropped = ["schemaVersion", "barHeight", "workspaceCount",
                                   "clockCity", "clockOffset", "barStyle", "barPosition",
                                   "islandBurnGuard", "rightLayout"]
                    var extras = {}
                    for (var k in data) {
                        if (Object.prototype.hasOwnProperty.call(data, k)
                                && dropped.indexOf(k) === -1)
                            extras[k] = data[k]
                    }
                    root.barConfigExtras = extras
                    // In save mode the disk copy is STALE by definition (the
                    // user just changed values in the UI) — refresh extras
                    // only; re-applying would silently revert the save.
                    if (!root._barConfigReadForSave) root.applyBarConfig(data)
                } catch (e) { /* keep empty extras */ }
            }
            barConfigRead.buffer = ""
            // A save chains through the re-read (extras refreshed above);
            // the actual write waits until here so it always lands, even if
            // the file was missing/unparseable (extras stay from startup).
            if (root._barConfigReadForSave) {
                root._barConfigReadForSave = false
                root._writeBarConfig()
            }
        }
    }

    // ── bar style discovery ────────────────────────────────────────────────
    // A style = a folder under ~/.config/quickshell/bar/styles/ with a
    // Scene.qml. Scanned at service init and on every BAR STYLE pick (new
    // style folders appear without restarting the settings shell).
    function scanBarStyles() {
        styleScanProc.running = true
    }

    Process {   // unbounded-ok: one-shot local command — timeout migration queued
        id: styleScanProc
        command: ["sh", "-c",
            "ls -1d '" + StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString().replace("file://", "") + "/quickshell/bar/styles/'*/Scene.qml 2>/dev/null | sed 's|.*/styles/||; s|/Scene.qml||' | sort"]
        // SplitParser delivers lines WITHOUT newlines (the documented trap) —
        // accumulating `buffer += data` concatenated style names into one
        // bogus "ryokuvector" entry. Collect per-line into an array instead.
        property var lines: []
        stdout: SplitParser { onRead: function(data) { styleScanProc.lines.push(String(data).trim()) } }
        onStarted: lines = []
        onExited: {
            var found = styleScanProc.lines.filter(function(l) { return l.length > 0 })
            styleScanProc.lines = []
            if (found.length > 0) root.barStyles = found
        }
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    Component.onCompleted: {
        loadSettings()
        barConfigRead.running = true
        scanBarStyles()
    }
}
