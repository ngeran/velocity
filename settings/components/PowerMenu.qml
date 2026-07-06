// =============================================================================
// FILE: PowerMenu.qml
// PROJECT: Obsidian Core — Quickshell Desktop Environment
// PURPOSE: Floating power menu overlay — Shutdown / Restart / Suspend / Lock
// DESIGN: Screen-proportional square panel, 2×2 action grid, circular uptime hub
// LAYER: WlrLayerShell.Overlay — sits above all windows, exclusive keyboard
// TRIGGER: Bind to keybind in your shell root (e.g. Meta+Shift+P)
// AUTHOR: ngeran
// VERSION: 0.2.0
// UPDATED: 2026-07
// =============================================================================
//
// CHANGELOG (0.1.0 -> 0.2.0):
//   - Panel size is now derived from Screen.width/height instead of a fixed
//     680x680 rect, so it no longer covers small/laptop displays.
//   - Removed the live SYSTEM_TIME digital clock from the central hub.
//   - Central hub now shows SYSTEM_UPTIME (previously only in the footer).
//   - Removed the now-redundant footer (uptime moved into the hub).
//   - Font sizes / spacing / radii scale off the computed panel size.
//   - Colors are untouched — everything still resolves through
//     Config.ThemeConfig.colors so the palette generator stays in control.
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
//   [4]  Main Container (proportional to screen size)
//   [5]  Header: Branding
//   [6]  Scanline Animation
//   [7]  Power Grid: 2×2 Tile Layout
//   [8]  PowerTile Component (inline)
//   [9]  Central Uptime Hub
//   [10] System Command Execution
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

    // -- Proportional sizing -------------------------------------------------
    // Panel is a square, sized as a fraction of the smaller screen dimension,
    // clamped so it stays comfortable on both small laptop panels and large
    // desktop monitors (e.g. your 3840x2160 QD-OLED).
    readonly property real screenMinDim: Math.min(Screen.width, Screen.height)
    readonly property int  panelSize:    Math.round(Math.max(360, Math.min(520, screenMinDim * 0.42)))

    // Scale factor relative to the original 680px design baseline — used to
    // keep fonts/spacing/radii proportional instead of just shrinking the box.
    readonly property real scale: panelSize / 680

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

    // -- [4] Main Container (proportional to screen size) --------------------
    Rectangle {
        id: container
        width:  root.panelSize
        height: root.panelSize
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
                topMargin:  Math.round(20 * root.scale)
                leftMargin: Math.round(20 * root.scale)
                rightMargin: Math.round(20 * root.scale)
            }
            spacing: 0

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Power Menu"
                    font.family:      "JetBrainsMono Nerd Font"
                    font.pixelSize:   Math.round(16 * root.scale)
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
            rowSpacing:    Math.round(14 * root.scale)
            columnSpacing: Math.round(14 * root.scale)
            anchors {
                top:    header.bottom
                bottom: parent.bottom
                left:   parent.left
                right:  parent.right
                topMargin:    Math.round(14 * root.scale)
                bottomMargin: Math.round(20 * root.scale)
                leftMargin:   Math.round(20 * root.scale)
                rightMargin:  Math.round(20 * root.scale)
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
                iconText:  "\uf023"
                labelText: "LOCK"
                onActivated: {
                    systemCmd.execute("hyprlock")
                    root.showing = false
                }
            }
        }

        // -- [9] Central Uptime Hub --------------------------------------------
        Rectangle {
            id: uptimeHub
            width:  Math.round(160 * root.scale)
            height: Math.round(160 * root.scale)
            radius: width / 2    // full circle
            anchors.centerIn: powerGrid

            color:  Config.ThemeConfig.colors.surface
            border.color: Config.ThemeConfig.colors.outline
            border.width: 1
            z: 20

            // Prevent click-through to tiles underneath
            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Math.round(4 * root.scale)
                width: parent.width * 0.82

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "SYSTEM_UPTIME"
                    font.family:      "JetBrainsMono Nerd Font"
                    font.pixelSize:   Math.max(8, Math.round(9 * root.scale))
                    font.weight:      Font.DemiBold
                    font.letterSpacing: 2.5
                    color: Config.ThemeConfig.colors.outline
                }

                Text {
                    id: uptimeDisplay
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    text: "--"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font.family:      "JetBrainsMono Nerd Font"
                    font.pixelSize:   Math.max(11, Math.round(15 * root.scale))
                    font.weight:      Font.ExtraBold
                    font.letterSpacing: -0.5
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
    }

    // -- [10] System Command Execution ----------------------------------------
    // Reads real system uptime from /proc/uptime, refreshed every 30s while
    // the menu is open, and rendered inside the central hub above.
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
        // Read /proc/uptime directly and format it ourselves — avoids relying
        // on `uptime -p` support, which varies across procps/busybox builds.
        command: ["bash", "-c",
            "s=$(cut -d. -f1 /proc/uptime); " +
            "d=$((s/86400)); h=$(((s%86400)/3600)); m=$(((s%3600)/60)); " +
            "if [ $d -gt 0 ]; then printf '%dd %dh %dm' $d $h $m; " +
            "elif [ $h -gt 0 ]; then printf '%dh %dm' $h $m; " +
            "else printf '%dm' $m; fi"
        ]
        stdout: SplitParser {
            onRead: data => {
                var t = data.trim()
                if (t.length > 0)
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
