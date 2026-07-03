// =============================================================================
// BarConfig.qml — Design tokens and configuration
// =============================================================================
//
// This singleton contains all visual design tokens for the bar.
// Colors are dynamically sourced from ThemeConfig for theme switching.
//
// SIZES
//   barHeight - Total bar height in pixels (configurable via bar-config.json)
//   iconSize - Size of each icon square
//   iconSpacing - Space between icons
//
// BEHAVIOR
//   workspaceCount - Number of workspace dots to display (configurable via bar-config.json)
//   *_interval - Polling intervals for services (milliseconds)
// =============================================================================

pragma Singleton

import QtQuick
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

    property string configFilePath: StandardPaths.writableLocation(StandardPaths.ConfigLocation)
                                       .replace("file://", "") + "/quickshell/bar-config.json"

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
            if (!running && configLoader.buffer.length > 0) {
                try {
                    var data = JSON.parse(configLoader.buffer)
                    if (data.barHeight !== undefined && [20, 26, 32, 40].indexOf(data.barHeight) !== -1) {
                        barHeight = data.barHeight
                        console.log("[BarConfig] Loaded barHeight:", barHeight)
                    }
                    if (data.workspaceCount !== undefined && [3, 5, 7, 9].indexOf(data.workspaceCount) !== -1) {
                        workspaceCount = data.workspaceCount
                        console.log("[BarConfig] Loaded workspaceCount:", workspaceCount)
                    }
                    if (data.clockCity !== undefined) {
                        clockCity = data.clockCity
                        console.log("[BarConfig] Loaded clockCity:", clockCity)
                    }
                    if (data.clockOffset !== undefined && data.clockOffset >= -12 && data.clockOffset <= 14) {
                        clockOffset = data.clockOffset
                        console.log("[BarConfig] Loaded clockOffset:", clockOffset)
                    }
                } catch (e) {
                    console.log("[BarConfig] Failed to parse config, using defaults:", e)
                }
                configLoader.buffer = ""
            }
        }
    }

    // =========================================================================
    // GEOMETRY
    // =========================================================================

    readonly property int barPadding: 12
    readonly property int iconSize: 32  // Increased from 20 for better clickability
    readonly property int iconSpacing: 4

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
    readonly property int fontSizeClock: 14
    readonly property int fontSizeIcon: 14

    // =========================================================================
    // WORKSPACES
    // =========================================================================

    readonly property int workspaceDotWidth: 6
    readonly property int workspaceDotWidthActive: 14
    readonly property int workspaceDotHeight: 6

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

    Component.onCompleted: {
        console.log("[BarConfig] Loading config from:", configFilePath)
        configLoader.command = ["cat", configFilePath]
        configLoader.running = true
    }
}
