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
    // =========================================================================
    // THEME COLORS (reactive - update when cache file changes)
    // =========================================================================

    property var colors: ({
        background: "#000000",
        surface: "#0a0a0a",
        surfaceVariant: "#111111",
        text: "#e0e0e0",
        textDim: "#808080",
        primary: "#7c6bf0",
        secondary: "#00dce5",
        accent: "#f87171",
        success: "#34d399",
        warning: "#fbbf24",
        error: "#f87171",
        info: "#00dce5",
        border: "#1a1a1a"
    })

    property var metadata: ({
        name: "Default",
        mode: "static",
        oledClamp: true
    })

    // =========================================================================
    // FILE WATCHING VIA PROCESS
    // =========================================================================

    // Plain filesystem path. StandardPaths returns a file:// URL in this Qt
    // build; strip it via .replace so `cat` gets a real path (a literal
    // "file://..." name doesn't exist → empty buffer → applyTheme never fires).
    property string themeFilePath: (StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.cache/theme/colors.json").replace("file://", "")
    property string buffer: ""

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
                try {
                    if (catProc.buffer.trim() !== "") {
                        console.log("[Bar ThemeConfig] Cache file read, applying theme")
                        ThemeConfig.applyTheme(JSON.parse(catProc.buffer))
                    }
                } catch (e) {
                    console.log("[Bar ThemeConfig] Parse error:", e)
                    // ignore parse errors — keep last good theme
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

    function applyTheme(data) {
        console.log("[Bar ThemeConfig] applyTheme called with theme:", data.metadata ? data.metadata.name : "unknown")
        if (data.colors) {
            colors = {
                background: data.colors.background || "#000000",
                surface: data.colors.surface || "#0a0a0a",
                surfaceVariant: data.colors.surfaceVariant || "#111111",
                text: data.colors.text || "#e0e0e0",
                textDim: data.colors.textDim || "#808080",
                primary: data.colors.primary || "#7c6bf0",
                secondary: data.colors.secondary || "#00dce5",
                accent: data.colors.accent || "#f87171",
                success: data.colors.success || "#34d399",
                warning: data.colors.warning || "#fbbf24",
                error: data.colors.error || "#f87171",
                info: data.colors.info || "#00dce5",
                border: data.colors.border || "#1a1a1a"
            }
        }

        if (data.metadata) {
            metadata = {
                name: data.metadata.name || "Unknown",
                mode: data.metadata.mode || "unknown",
                oledClamp: data.metadata.oledClamp || false
            }
        }
    }
}
