// =============================================================================
// BarConfig.qml — Design tokens and configuration
// =============================================================================
//
// This singleton contains all visual design tokens for the bar.
// Colors are dynamically sourced from ThemeConfig for theme switching.
//
// SIZES
//   barHeight  - Total bar height in pixels (configurable via bar-config.json)
//   iconSize   - Size of each icon square (scales with barHeight)
//   iconSpacing - Space between icons
//
// BEHAVIOR
//   workspaceCount - Number of workspace dots to display (configurable via bar-config.json)
//   *_interval - Polling intervals for services (milliseconds)
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
import Quickshell.Io

Item {
    id: root
    visible: false
    // =========================================================================
    // CONFIGURABLE SETTINGS (loaded from bar-config.json)
    // =========================================================================

    // Default values - overridden by config file if present
    property int barHeight: 26
    property int workspaceCount: 5
    property string clockCity: "Local"
    property int clockOffset: 0

    // =========================================================================
    // CONFIG FILE LOADING
    // =========================================================================

    property string configFilePath: StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString().replace("file://", "") + "/quickshell/bar-config.json"
    property string _lastRaw: ""   // dedup: only re-apply when bar-config.json actually changes

    Process {
        id: configLoader
        command: []
        running: false

        property string buffer: ""

        stdout: SplitParser {
            onRead: function(data) {
                configLoader.buffer += data
            }
        }

        onRunningChanged: {
            if (!running) {
                var raw = configLoader.buffer
                configLoader.buffer = ""
                if (raw.length === 0 || raw === _lastRaw) return  // dedup: skip empty/unchanged
                _lastRaw = raw
                try {
                    var data = JSON.parse(raw)
                    if (data.barHeight !== undefined && [20, 26, 32, 40].indexOf(data.barHeight) !== -1)
                        barHeight = data.barHeight
                    if (data.workspaceCount !== undefined && [3, 5, 7, 9].indexOf(data.workspaceCount) !== -1)
                        workspaceCount = data.workspaceCount
                    if (data.clockCity !== undefined)
                        clockCity = data.clockCity
                    if (data.clockOffset !== undefined && data.clockOffset >= -12 && data.clockOffset <= 14)
                        clockOffset = data.clockOffset
                    console.log("[BarConfig] Hot-reloaded bar-config.json")
                } catch (e) {
                    console.log("[BarConfig] Failed to parse config:", e)
                }
            }
        }
    }

    // =========================================================================
    // GEOMETRY
    // =========================================================================

    // barHeight is configurable ([20, 26, 32, 40]). Every visible item in the
    // bar scales off this baseline so the bar stays proportional at any height
    // — icons, clock text, and workspace dots all grow/shrink together instead
    // of floating unchanged inside a taller bar. Baseline = 26px (the default),
    // so _contentScale is 1.0 at the default and the default look is preserved.
    readonly property real _contentScale: root.barHeight / 26.0

    readonly property int barPadding: 12
    readonly property int iconSize: Math.round(32 * _contentScale)   // tray-icon slot
    readonly property int iconSpacing: 4
    readonly property int archLogoSize: Math.round(15 * _contentScale)

    // =========================================================================
    // COLOURS (Dynamic from ThemeConfig)
    // =========================================================================

    readonly property color colorBackground: ThemeConfig.colors.background
    readonly property color colorAccent: ThemeConfig.colors.secondary
    readonly property color colorText: ThemeConfig.colors.text
    readonly property color colorTextDim: ThemeConfig.colors.textDim
    readonly property color colorMuted: ThemeConfig.colors.error
    readonly property color colorBorder: ThemeConfig.colors.border

    // =========================================================================
    // TYPOGRAPHY
    // =========================================================================

    readonly property string fontFamily: "monospace"
    readonly property string fontNerd: "JetBrainsMono Nerd Font"
    readonly property int fontSizeClock: Math.max(10, Math.round(14 * _contentScale))
    readonly property int fontSizeDate: Math.max(7, Math.round(9 * _contentScale))
    readonly property int fontSizeIcon: Math.max(10, Math.round(14 * _contentScale))   // tray glyph

    // =========================================================================
    // WORKSPACES
    // =========================================================================

    readonly property int workspaceDotWidth: Math.max(3, Math.round(6 * _contentScale))
    readonly property int workspaceDotWidthActive: Math.round(14 * _contentScale)
    readonly property int workspaceDotHeight: Math.max(3, Math.round(6 * _contentScale))
    readonly property int workspaceButtonSize: Math.round(24 * _contentScale)
    readonly property int workspaceButtonFontSize: Math.max(8, Math.round(11 * _contentScale))

    // =========================================================================
    // POLLING INTERVALS (milliseconds)
    // =========================================================================

    readonly property int networkInterval: 3000
    readonly property int bluetoothInterval: 6000
    readonly property int audioInterval: 3000
    readonly property int workspaceInterval: 1500

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    // Poll bar-config.json every 2s so the bar picks up Settings-tab changes
    // (bar height, workspace dots, clock offset/city) without a restart. Mirrors
    // the theme poller in ThemeConfig.qml; dedup avoids redundant re-application.
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: { configLoader.command = ["cat", configFilePath]; configLoader.running = true }
    }

    Component.onCompleted: {
        console.log("[BarConfig] Loading config from:", configFilePath)
        configLoader.command = ["cat", configFilePath]
        configLoader.running = true
    }
}
