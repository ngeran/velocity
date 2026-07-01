// =============================================================================
// FILE: PowerMenu.qml
// PROJECT: Obsidian Core — Quickshell Desktop Environment
// PURPOSE: Floating power menu overlay — Shutdown / Restart / Suspend / Lock
// DESIGN: 680×680 centered panel, 2×2 action grid, circular clock hub, scanline
// LAYER: WlrLayerShell.Overlay — sits above all windows, exclusive keyboard
// TRIGGER: Bind to keybind in your shell root (e.g. Meta+Shift+P)
// AUTHOR: ngeran
// VERSION: 0.1.0
// UPDATED: 2025-06
// =============================================================================
//
// DEPENDENCIES:
//   - Quickshell (PanelWindow, WlrLayerShell, ShellConstants)
//   - Quickshell.Io (Process)
//   - QtQuick, QtQuick.Layouts, QtQuick.Effects
//
// SECTIONS:
//   [1]  Imports
//   [2]  PanelWindow / Layer-shell Setup
//   [3]  Background Overlay Dimmer
//   [4]  Main Container (680×680)
//   [5]  Header: Branding
//   [6]  Scanline Animation
//   [7]  Power Grid: 2×2 Tile Layout
//   [8]  PowerTile Component (inline)
//   [9]  Central Clock Hub
//   [10] Footer: System Uptime
//   [11] Clock Timer Logic
//   [12] System Command Execution
// =============================================================================

// -- [1] Imports --------------------------------------------------------------
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../config" as Config
import "." as Components

// -- [2] PanelWindow / Layer-shell Setup --------------------------------------
PanelWindow {
    id: root

    // Visible state — toggled externally by your shell root keybind
    property bool showing: false

    // Layer-shell config (Quickshell 0.3.0 direct properties — NOT WlrLayerShell.* attached):
    // render above normal windows + accept keyboard input (Escape to close).
    aboveWindows: true
    focusable: true

    // Fill entire screen so we can dim the background
    anchors {
        top:    true
        bottom: true
        left:   true
        right:  true
    }

    // Transparent window background — dimmer drawn inside
    color: "transparent"

    visible: showing

    // Close on Escape
    Keys.onEscapePressed: root.showing = false

    // -- [3] Background Overlay Dimmer ----------------------------------------
    Rectangle {
        anchors.fill: parent
        color: Config.ThemeConfig.colors.background
        opacity: 0.85

        // Click-outside-to-close area
        MouseArea {
            anchors.fill: parent
            onClicked: root.showing = false
        }
    }

    // -- [4] Main Container (680×680) -----------------------------------------
    Rectangle {
        id: container
        width:  680
        height: 680
        anchors.centerIn: parent

        color:  Config.ThemeConfig.colors.surface
        border.color: Config.ThemeConfig.colors.outline
        border.width: 1

        // Subtle outer glow
        layer.enabled: true
        layer.effect: null   // attach a DropShadow if QtQuick.Effects available

        // Prevent click-through to dimmer
        MouseArea { anchors.fill: parent }

        // -- [5] Header: Branding ----------------------------------------------
        ColumnLayout {
            id: header
            anchors {
                top:   parent.top
                left:  parent.left
                right: parent.right
                topMargin:  24
                leftMargin: 24
                rightMargin: 24
            }
            spacing: 0

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Power Menu"
                    font.family:      "JetBrainsMono Nerd Font"
                    font.pixelSize:   18
                    font.weight:      Font.DemiBold
                    font.letterSpacing: -0.18
                    color: Config.ThemeConfig.colors.text
                    font.capitalization: Font.AllUppercase
                }

                Item { Layout.fillWidth: true }
            }
        }

        // -- [6] Scanline Animation -------------------------------------------
        Rectangle {
            id: scanline
            width:  parent.width
            height: 2
            color:  Qt.rgba(Config.ThemeConfig.colors.secondary.r, Config.ThemeConfig.colors.secondary.g, Config.ThemeConfig.colors.secondary.b, 0.10)
            z: 5

            SequentialAnimation on y {
                loops: Animation.Infinite
                NumberAnimation {
                    from: 0
                    to:   container.height
                    duration: 8000
                    easing.type: Easing.Linear
                }
            }
        }

        // -- [7] Power Grid: 2×2 Tile Layout ----------------------------------
        GridLayout {
            id: powerGrid
            columns: 2
            rowSpacing:    16
            columnSpacing: 16
            anchors {
                top:    header.bottom
                bottom: footer.top
                left:   parent.left
                right:  parent.right
                topMargin:    16
                bottomMargin: 16
                leftMargin:   24
                rightMargin:  24
            }

            // -- [8] PowerTile Instances ---------------------------------------
            Components.PowerTile {
                Layout.fillWidth:  true
                Layout.fillHeight: true
                iconText:  "⏻"
                labelText: "SHUTDOWN"
                onActivated: systemCmd.execute("systemctl poweroff")
            }
            Components.PowerTile {
                Layout.fillWidth:  true
                Layout.fillHeight: true
                iconText:  "↺"
                labelText: "RESTART"
                onActivated: systemCmd.execute("systemctl reboot")
            }
            Components.PowerTile {
                Layout.fillWidth:  true
                Layout.fillHeight: true
                iconText:  "☾"
                labelText: "SUSPEND"
                onActivated: systemCmd.execute("systemctl suspend")
            }
            Components.PowerTile {
                Layout.fillWidth:  true
                Layout.fillHeight: true
                iconText:  "🔒"
                labelText: "LOCK"
                onActivated: {
                    systemCmd.execute("hyprlock")
                    root.showing = false
                }
            }
        }

        // -- [9] Central Clock Hub --------------------------------------------
        Rectangle {
            id: clockHub
            width:  200
            height: 200
            radius: 100    // full circle
            anchors.centerIn: powerGrid

            color:  Config.ThemeConfig.colors.surface
            border.color: Config.ThemeConfig.colors.outline
            border.width: 1
            z: 20

            // Prevent click-through to tiles underneath
            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "SYSTEM_TIME"
                    font.family:      "JetBrainsMono Nerd Font"
                    font.pixelSize:   11
                    font.weight:      Font.DemiBold
                    font.letterSpacing: 5.5
                    color: Config.ThemeConfig.colors.outline
                }

                Text {
                    id: clockDisplay
                    Layout.alignment: Qt.AlignHCenter
                    text: "00:00:00"
                    font.family:      "JetBrainsMono Nerd Font"
                    font.pixelSize:   28
                    font.weight:      Font.ExtraBold
                    font.letterSpacing: -1
                    color: Config.ThemeConfig.colors.text
                }

                // Pulse dots
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4

                    Repeater {
                        model: 3
                        Rectangle {
                            width: 4; height: 4; radius: 2
                            color: Config.ThemeConfig.colors.secondary
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.2; duration: 600 + index * 75; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 600 + index * 75; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }
            }
        }

        // -- [10] Footer: System Uptime -----------------------------------------
        RowLayout {
            id: footer
            anchors {
                bottom: parent.bottom
                left:   parent.left
                right:  parent.right
                bottomMargin: 24
                leftMargin:   24
                rightMargin:  24
            }

            ColumnLayout {
                spacing: 4
                Text {
                    text: "SYSTEM_UPTIME"
                    font.family:      "JetBrainsMono Nerd Font"
                    font.pixelSize:   11
                    font.letterSpacing: 3
                    color: Config.ThemeConfig.colors.outline
                }
                Text {
                    id: uptimeDisplay
                    text: "--"
                    font.family:      "JetBrainsMono Nerd Font"
                    font.pixelSize:   13
                    font.weight:      Font.DemiBold
                    font.letterSpacing: 0.5
                    color: Config.ThemeConfig.colors.text
                }
            }

            Item { Layout.fillWidth: true }
        }

        // Top border line above footer
        Rectangle {
            anchors {
                bottom: footer.top
                left:   parent.left
                right:  parent.right
                bottomMargin: 8
                leftMargin:   24
                rightMargin:  24
            }
            height: 1
            color:  Config.ThemeConfig.colors.outlineVariant
        }
    }

    // -- [11] Clock Timer Logic -----------------------------------------------
    Timer {
        interval: 1000
        running:  root.showing
        repeat:   true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            var h = String(now.getHours()).padStart(2, '0')
            var m = String(now.getMinutes()).padStart(2, '0')
            var s = String(now.getSeconds()).padStart(2, '0')
            clockDisplay.text = h + ":" + m + ":" + s
        }
    }

    // -- [12] System Command Execution ----------------------------------------
    // Reads real system uptime from /proc/uptime (independent of the live clock above)
    Timer {
        id: uptimeTimer
        interval: 30000
        running:  root.showing
        repeat:   true
        triggeredOnStart: true
        onTriggered: uptimeProbe.running = true
    }

    Process {
        id: uptimeProbe
        command: ["bash", "-c", "uptime -p"]
        stdout: SplitParser {
            onRead: data => {
                // "up 3 hours, 12 minutes" -> "3 HOURS, 12 MINUTES"
                var t = data.trim().replace(/^up\s+/i, "")
                uptimeDisplay.text = t.toUpperCase()
            }
        }
    }

    // Deferred executor — set .command then call .startDetached()
    Process {
        id: systemCmd
        function execute(cmd) {
            systemCmd.command = ["bash", "-c", cmd]
            systemCmd.running = true
            root.showing = false
        }
    }
}
