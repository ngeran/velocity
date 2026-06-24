// =============================================================================
// ThemeConfig.qml — Dynamic Theme Singleton
// =============================================================================
//
// This singleton provides dynamic theme configuration by watching
// ~/.cache/theme/colors.json for changes. When the theme file changes,
// all properties automatically update, triggering reactive updates across
// all QuickShell components.
//
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
import Quickshell.Io

Item {
    id: root
    visible: false

    // Flag to prevent polling from overwriting user-initiated changes
    property bool userInitiatedChange: false

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
    // FILE WATCHING VIA PROCESS
    // =========================================================================

    // Plain filesystem path. StandardPaths returns a file:// URL in this Qt
    // build; strip it via .replace so `cat` gets a real path (a literal
    // "file://..." name doesn't exist → empty buffer → applyTheme never fires).
    property string themeFilePath: (StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.cache/theme/colors.json").replace("file://", "")
    property string lastCachedData: ""

    // =========================================================================
    // SINGLE-TOKEN MUTATION HELPER
    // -------------------------------------------------------------------------
    // Nested var keys do not emit change signals on in-place edit, so the whole
    // object is rebuilt and reassigned. This forces QML to re-evaluate every
    // binding that reads colors.<key>.
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

    // Poll colors.json every second. Mirrors NetworkService's PROVEN pattern
    // EXACTLY: `sh -c "cat <file>"` (a bare `cat`/onExited combo failed to
    // deliver stdout in this build), SplitParser accumulates, onRunningChanged
    // parses + applies when cat finishes.
    Process {
        id: catProc
        command: ["sh", "-c", "cat " + ThemeConfig.themeFilePath]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { catProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                if (catProc.buffer.trim().length > 0) {
                    try {
                        var newData = catProc.buffer.trim()
                        // Only apply if data has actually changed AND not a user-initiated change
                        if (newData !== root.lastCachedData) {
                            if (!root.userInitiatedChange) {
                                console.log("[Bar ThemeConfig] Cache data changed (external), re-applying theme")
                                root.lastCachedData = newData
                                ThemeConfig.applyTheme(JSON.parse(newData))
                            } else {
                                console.log("[Bar ThemeConfig] Cache data changed but user initiated, skipping")
                                root.lastCachedData = newData  // Update last cached data but don't apply
                                root.userInitiatedChange = false  // Reset flag
                            }
                        } else {
                            console.log("[Bar ThemeConfig] Cache data unchanged, skipping re-application")
                        }
                    } catch (e) {
                        console.log("[Bar ThemeConfig] Parse error:", e)
                        // ignore parse errors — keep last good theme
                    }
                }
                catProc.buffer = ""
            }
        }
    }

    Timer {
        interval: 300   // poll every 300ms so the bar follows theme switches with minimal lag
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!catProc.running) catProc.running = true }
    }

    // =========================================================================
    // THEME APPLICATION
    // =========================================================================

    function applyTheme(data, isUserInitiated) {
        console.log("[Bar ThemeConfig] applyTheme called with theme:", data.metadata ? data.metadata.name : "unknown")

        // Set flag if this is a user-initiated change
        if (isUserInitiated === true) {
            root.userInitiatedChange = true
            console.log("[Bar ThemeConfig] Set userInitiatedChange flag")
        }

        if (!data) {
            console.log("[Bar ThemeConfig] ERROR: No data provided")
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
            console.log("[Bar ThemeConfig] Colors applied. New background:", root.colors.background)
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
            console.log("[Bar ThemeConfig] Metadata applied. oledClamp:", root.metadata.oledClamp)
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
            console.log("[Bar ThemeConfig] OLED clamp applied")
        }
    }
}
