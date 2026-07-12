// =============================================================================
// shell.qml — QuickShell Settings Dashboard Entry Point
//
// This is the entry point QuickShell auto-discovers and launches.
// It sets up a transparent full-width top stage + centered sliding card
// that animates down from the bar (26px tall). The card's top edge aligns
// with the bar's bottom when shown.
//
// All visual content lives in ModernDashboard.qml — this file only handles
// the window geometry, animation, and IPC dispatch.
//
// =============================================================================

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "components" as Components
import "config" as Config

ShellRoot {
    id: root

    // =========================================================================
    // STATE
    // =========================================================================

    property bool shown: false

    // Screen-adaptive sizing — scale based on available window dimensions.
    // PanelWindow spans the full screen, so its width/height map to the screen.
    readonly property real availableWidth: panelWindow.width || 1920
    readonly property real availableHeight: panelWindow.height || 1080

    // Base design size (1100×640) — the perfect size on the 4K OLED. On smaller
    // screens each dimension is capped to a fraction of the panel so the card
    // never swamps the display (a fixed 640px height covered ~all of a 768p
    // laptop); floors keep it usable on tiny screens. Caps preserve the 4K look.
    readonly property real cardWidth:  Math.max(720, Math.min(1100, availableWidth  * 0.60))
    readonly property real cardHeight: Math.max(480, Math.min(640,  availableHeight * 0.75))

    // =========================================================================
    // HIDE TIMER — defer visible=false until slide-up completes
    // =========================================================================
    Timer {
        id: hideTimer
        interval: Config.SettingsConfig.animDurationSlow

        onTriggered: {
            if (!root.shown) {
                panelWindow.visible = false
            }
        }
    }

    // Trigger hide timer when shown becomes false
    onShownChanged: {
        if (!shown) {
            hideTimer.restart()
        }
    }

    // =========================================================================
    // WORKSPACE WATCHER — auto-close when the user switches workspace.
    // Event-driven via Hyprland's socket2 (no polling latency). socat streams
    // events line-by-line; we dismiss on workspace>> / workspacev2>> /
    // focusedmon>> (focus moving to another monitor is effectively a switch).
    // =========================================================================
    Process {
        id: workspaceWatcher
        command: ["sh", "-c", "socat -u UNIX-CONNECT:\"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock\" -"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var ev = "" + line
                if (ev.indexOf("workspace>>") === 0
                    || ev.indexOf("workspacev2>>") === 0
                    || ev.indexOf("focusedmon>>") === 0) {
                    if (root.shown) root.shown = false
                }
            }
        }
    }

    // =========================================================================
    // IPC HANDLER — toggle window visibility from other instances (e.g. bar)
    // =========================================================================
    IpcHandler {
        id: settingsWindowIpc
        target: "SettingsWindow"

        function toggle() {
            if (panelWindow.visible && !root.shown) {
                // Already hiding — do nothing
                return
            }
            root.shown = !root.shown
            panelWindow.visible = true
            // Reset to the Dashboard tab each time the panel is opened.
            if (root.shown) dashboard.currentTab = 0
        }

        function show() {
            root.shown = true
            panelWindow.visible = true
            // Reset to the Dashboard tab each time the panel is opened.
            dashboard.currentTab = 0
        }

        function hide() {
            root.shown = false
        }

        // Deep-link to Control tab sections (Quickshell IPC doesn't support
        // arbitrary arguments, so individual functions per section)
        function openControlNetwork() {
            root.shown = true
            panelWindow.visible = true
            dashboard.openControlTab("network")
        }

        function openControlBluetooth() {
            root.shown = true
            panelWindow.visible = true
            dashboard.openControlTab("bluetooth")
        }

        function openControlAudio() {
            root.shown = true
            panelWindow.visible = true
            dashboard.openControlTab("audio")
        }

        function openControlPower() {
            root.shown = true
            panelWindow.visible = true
            dashboard.openControlTab("power")
        }

        function openControlSystem() {
            root.shown = true
            panelWindow.visible = true
            dashboard.openControlTab("system")
        }
    }

    // =========================================================================
    // IPC HANDLER — toggle the PowerMenu overlay (bar PowerIcon / SUPER+P)
    // =========================================================================
    IpcHandler {
        id: powerMenuIpc
        target: "powerMenu"

        function toggle() {
            powerMenu.showing = !powerMenu.showing
        }
    }

    // =========================================================================
    // PANEL WINDOW — transparent full-width top stage
    // =========================================================================
    PanelWindow {
        id: panelWindow

        // Full-screen overlay so ANY click outside the card closes the window.
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        // Transparent stage — backdrop + card provide the visuals
        color: "transparent"

        // Don't reserve screen space
        exclusionMode: ExclusionMode.Ignore

        // Stay above other windows
        aboveWindows: true

        // Allow keyboard focus (Escape to close)
        focusable: true

        // Start hidden
        visible: false

        // Dim backdrop — also makes the surface input-solid so clicks register
        // anywhere outside the card. (A bare MouseArea on a transparent layer
        // doesn't catch input in Wayland — the dim Rectangle is what registers
        // the input region.) Fades in/out with the card.
        Rectangle {
            id: backdrop
            anchors.fill: parent
            color: Config.ThemeConfig.colors.background
            opacity: root.shown ? 0.6 : 0.0
            visible: opacity > 0.01
            Behavior on opacity {
                NumberAnimation { duration: Config.SettingsConfig.animDurationSlow }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: root.shown = false
            }
        }

        // Key handler — Escape closes
        Keys.onEscapePressed: {
            root.shown = false
        }

        // =====================================================================
        // DASHBOARD CARD — centered, animates down from bar
        // =====================================================================
        Components.ModernDashboard {
            id: dashboard

            z: 1   // paint above the dim backdrop
            width: root.cardWidth
            height: root.cardHeight

            // Center horizontally, animate vertically
            anchors.horizontalCenter: parent.horizontalCenter

            // Hidden: y = barHeight - height (above stage)
            // Shown:  y = barHeight (top edge flush with bar bottom)
            y: root.shown ? Config.SettingsConfig.barHeight : (Config.SettingsConfig.barHeight - height)

            // Smooth slide animation
            Behavior on y {
                NumberAnimation {
                    duration: Config.SettingsConfig.animDurationSlow
                    easing.type: Easing.OutCubic
                }
            }

            // Focus handling — close when losing focus to outside
            focus: true

            Keys.onEscapePressed: {
                root.shown = false
            }
        }
    }

    // =========================================================================
    // POWER MENU — full-screen overlay (toggled via the 'powerMenu' IPC target)
    // =========================================================================
    Components.PowerMenu {
        id: powerMenu
    }
}
