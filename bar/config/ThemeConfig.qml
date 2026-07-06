// =============================================================================
// bar/config/ThemeConfig.qml — Dynamic Theme Singleton
// =============================================================================
//
// This singleton provides dynamic theme configuration by watching
// ~/.cache/theme/colors.json for changes. When the theme file changes,
// all properties automatically update, triggering reactive updates across
// all QuickShell components.
//
// Reads ~/.cache/theme/colors.json via FileView.onFileChanged (event-driven,
// instant updates when settings or external tools write the file).
//
// =============================================================================
// SYNC WITH: settings/config/ThemeConfig.qml — applyTheme(), updateColorToken(),
// and colors/metadata defaults MUST match (bar + settings are separate processes).
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
import Quickshell.Io
import "." as Config

Item {
    id: root
    visible: false

    // =========================================================================
    // THEME COLORS (reactive - update when cache file changes)
    // =========================================================================

    property var colors: ({
        // --- Tier 1: Structural Foundations ---
        "background":      "#000000",
        "surface":         "#0a0a0a",
        "surfaceVariant":  "#111111",
        "surfaceContainer":"#111111",
        "text":            "#e0e0e0",
        "textDim":         "#808080",
        "border":          "#1a1a1a",
        "outline":         "#2a2a2a",
        "outlineVariant":  "#1a1a1a",
        // --- Tier 2: Accent Fields (mutable) ---
        "primary":         "#7c6bf0",
        "secondary":       "#00dce5",
        "accent":          "#f87171",
        "success":         "#34d399",
        "warning":         "#fbbf24",
        "error":           "#f87171",
        "info":            "#00dce5"
    })

    property var metadata: ({
        "name":           "OLED Pure Black",
        "source":         "preset",
        "applied":        "",
        "oledClamp":      true,
        "matugenEnabled": false
    })

    // =========================================================================
    // THEME FILE PATH
    // =========================================================================

    readonly property string themeFilePath: (StandardPaths.writableLocation(StandardPaths.HomeLocation).toString() + "/.cache/theme/colors.json").replace("file://", "")
    property string lastCachedData: ""

    // =========================================================================
    // SINGLE-TOKEN MUTATION HELPER
    // =========================================================================

    function updateColorToken(key, value) {
        var next = {}
        var k
        for (k in root.colors) {
            if (Object.prototype.hasOwnProperty.call(root.colors, k)) {
                next[k] = root.colors[k]
            }
        }
        next[key] = value
        root.colors = next
    }

    // =========================================================================
    // THEME APPLICATION
    // =========================================================================

    function applyTheme(data) {
        if (Config.DebugConfig.debugTheme) console.log("[Bar ThemeConfig] applyTheme called with theme:", data.metadata ? data.metadata.name : "unknown")

        if (!data) {
            if (Config.DebugConfig.debugTheme) console.log("[Bar ThemeConfig] ERROR: No data provided")
            return
        }

        if (data.colors) {
            var c = data.colors
            root.colors = {
                // Tier 1
                "background":       c.background       || root.colors.background,
                "surface":          c.surface          || root.colors.surface,
                "surfaceVariant":   c.surfaceVariant   || root.colors.surfaceVariant,
                "surfaceContainer": c.surfaceContainer || c.surfaceVariant || root.colors.surfaceContainer,
                "text":             c.text             || root.colors.text,
                "textDim":          c.textDim          || root.colors.textDim,
                "border":           c.border           || root.colors.border,
                "outline":          c.outline          || root.colors.outline,
                "outlineVariant":   c.outlineVariant   || root.colors.outlineVariant,
                // Tier 2
                "primary":          c.primary          || root.colors.primary,
                "secondary":        c.secondary        || root.colors.secondary,
                "accent":           c.accent           || root.colors.accent,
                "success":          c.success          || root.colors.success,
                "warning":          c.warning          || root.colors.warning,
                "error":            c.error            || root.colors.error,
                "info":             c.info             || root.colors.info
            }
            if (Config.DebugConfig.debugTheme) console.log("[Bar ThemeConfig] Colors applied. New background:", root.colors.background)
        }

        if (data.metadata) {
            var m = data.metadata
            var newOledClamp = (m.oledClamp !== undefined) ? m.oledClamp : root.metadata.oledClamp

            root.metadata = {
                "name":           m.name           || root.metadata.name,
                "source":         m.source         || (m.mode || root.metadata.source),
                "applied":        m.applied        || root.metadata.applied,
                "oledClamp":      newOledClamp,
                "matugenEnabled": (m.matugenEnabled !== undefined) ? m.matugenEnabled : root.metadata.matugenEnabled
            }
            if (Config.DebugConfig.debugTheme) console.log("[Bar ThemeConfig] Metadata applied. oledClamp:", root.metadata.oledClamp)
        }

        // QD-OLED Safe: force pure-black backgrounds
        if (root.metadata.oledClamp) {
            var cb = {}
            for (var kb in root.colors) cb[kb] = root.colors[kb]
            cb.background = "#000000"
            cb.surface = "#000000"
            cb.surfaceVariant = "#000000"
            cb.surfaceContainer = "#000000"
            root.colors = cb
            if (Config.DebugConfig.debugTheme) console.log("[Bar ThemeConfig] OLED clamp applied")
        }
    }

    // =========================================================================
    // EXTERNAL INTAKE — FileView.onFileChanged watching colors.json
    // -------------------------------------------------------------------------
    // Event-driven sync (replaces 1s poll). Reacts instantly to writes from
    // settings (ThemeService) and external tools (theme-switcher CLI).
    // FileView.text is a METHOD in this Quickshell build, not a property.
    // =========================================================================

    property string lastCachedTimestamp: ""

    // Polling timer for theme sync (FileView.onFileChanged doesn't fire reliably)
    Timer {
        id: cachePoller
        interval: 1000  // Check every 1 second
        running: true
        repeat: true
        onTriggered: themePoller.running = true
    }

    // Poller process for checking theme file changes
    Process {
        id: themePoller
        command: ["cat", root.themeFilePath]
        property string pollBuffer: ""
        stdout: SplitParser {
            onRead: function(data) {
                themePoller.pollBuffer += data
            }
        }
        onExited: function(code) {
            if (!themePoller.pollBuffer || themePoller.pollBuffer.trim() === "") return
            try {
                var newData = themePoller.pollBuffer.trim()
                // Check if data actually changed
                if (newData === root.lastCachedData) {
                    themePoller.pollBuffer = ""
                    return
                }

                var dataObj = JSON.parse(newData)
                var newTimestamp = (dataObj.metadata && dataObj.metadata.applied) ? dataObj.metadata.applied : ""
                if (newTimestamp === root.lastCachedTimestamp && newData === root.lastCachedData) {
                    themePoller.pollBuffer = ""
                    return  // No actual change
                }

                if (Config.DebugConfig.debugTheme) console.log("[Bar ThemeConfig] Cache file changed, re-applying theme")

                root.lastCachedTimestamp = newTimestamp
                root.lastCachedData = newData
                root.applyTheme(dataObj)
            } catch (e) {
                // Silent retry on parse error (file might be mid-write)
            }
            themePoller.pollBuffer = ""
        }
    }

    // Startup restore: FileView doesn't fire for an already-existing file at
    // launch, so explicitly read colors.json once on completion to restore the
    // last-applied theme from the previous session.
    Component.onCompleted: startupReader.running = true

    Process {
        id: startupReader
        command: ["sh", "-c", "cat " + root.themeFilePath]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { startupReader.buffer += data } }
        onRunningChanged: {
            if (!running && startupReader.buffer.trim().length > 0) {
                try {
                    var raw = startupReader.buffer.trim()
                    var data = JSON.parse(raw)
                    root.lastCachedData = raw
                    if (data.metadata && data.metadata.applied) root.lastCachedTimestamp = data.metadata.applied
                    root.applyTheme(data)
                    if (Config.DebugConfig.debugTheme) console.log("[Bar ThemeConfig] Startup theme restored")
                } catch (e) {
                    // No/invalid cache yet — keep defaults
                    if (Config.DebugConfig.debugTheme) console.log("[Bar ThemeConfig] No cache file, using defaults")
                }
                startupReader.buffer = ""
            }
        }
    }
}
