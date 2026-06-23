// =============================================================================
// ThemeConfig.qml — theme cache poller for the control process
// =============================================================================
//
// The control process is a SEPARATE quickshell instance (quickshell -c control)
// and cannot share the settings/bar singletons. It follows the SAME sync
// contract as the bar: poll ~/.cache/theme/colors.json (written by the settings
// ThemeService) and re-apply. Only structural tokens are consumed here; the
// cyan terminal accent lives in ControlConfig and is intentionally fixed.
//
// Adapted from bar/config/ThemeConfig.qml — same proven `sh -c "cat <path>"`
// + SplitParser pattern, file:// stripping, 500 ms poll.
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
import Quickshell.Io

Item {
    id: root
    visible: false

    property var colors: ({
        background:      "#000000",
        surface:         "#0a0a0a",
        surfaceVariant:  "#111111",
        text:            "#e2e2e2",
        textDim:         "#8e9192",
        primary:         "#7c6bf0",
        secondary:       "#00dce5",
        accent:          "#f87171",
        success:         "#34d399",
        warning:         "#fbbf24",
        error:           "#f87171",
        info:            "#00dce5",
        border:          "#262626"
    })

    property var metadata: ({
        name: "Default",
        mode: "static",
        oledClamp: true
    })

    // StandardPaths returns a file:// URL in this Qt build — strip it or `cat`
    // gets a literal "file://..." name that does not exist (empty buffer).
    property string themeFilePath: (StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.cache/theme/colors.json").replace("file://", "")

    Process {
        id: catProc
        command: ["sh", "-c", "cat " + root.themeFilePath]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { catProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                try {
                    if (catProc.buffer.trim() !== "") {
                        root.applyTheme(JSON.parse(catProc.buffer))
                    }
                } catch (e) {
                    // ignore parse errors — keep last good theme
                }
                catProc.buffer = ""
            }
        }
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!catProc.running) catProc.running = true }
    }

    function applyTheme(data) {
        if (data.colors) {
            var c = data.colors
            root.colors = {
                background:      c.background      || root.colors.background,
                surface:         c.surface         || root.colors.surface,
                surfaceVariant:  c.surfaceVariant  || root.colors.surfaceVariant,
                text:            c.text            || root.colors.text,
                textDim:         c.textDim         || root.colors.textDim,
                primary:         c.primary         || root.colors.primary,
                secondary:       c.secondary       || root.colors.secondary,
                accent:          c.accent          || root.colors.accent,
                success:         c.success         || root.colors.success,
                warning:         c.warning         || root.colors.warning,
                error:           c.error           || root.colors.error,
                info:            c.info            || root.colors.info,
                border:          c.border          || root.colors.border
            }
        }
        if (data.metadata) {
            var m = data.metadata
            root.metadata = {
                name: m.name || "Unknown",
                mode: m.mode || "unknown",
                oledClamp: m.oledClamp !== undefined ? m.oledClamp : false
            }
        }
    }
}
