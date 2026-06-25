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
        }

        function show() {
            root.shown = true
            panelWindow.visible = true
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

        // Full-width transparent stage
        anchors {
            top: true
            left: true
            right: true
        }

        // Height = bar (26) + card (640) + margin (14) = 680
        implicitHeight: Config.SettingsConfig.barHeight + 640 + 14
        implicitWidth:  1920

        // Transparent stage — card provides the background
        color: "transparent"

        // Don't reserve screen space
        exclusionMode: ExclusionMode.Ignore

        // Stay above other windows
        aboveWindows: true

        // Allow keyboard focus (Escape to close)
        focusable: true

        // Start hidden
        visible: false

        // Full-stage mouse area closes on outside-click
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: {
                root.shown = false
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

            width: 1100
            height: 640

            // Center horizontally, animate vertically
            anchors.horizontalCenter: parent.horizontalCenter

            // Hidden: y = barHeight - height = 26 - 640 = -614 (above stage)
            // Shown:  y = barHeight = 26 (top edge flush with bar bottom)
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
