// =============================================================================
// shell.qml — QuickShell Settings Dashboard Entry Point
//
// This is the entry point QuickShell auto-discovers and launches.
// It only sets up the PanelWindow + IPC handler, then delegates ALL layout
// to ModernDashboard.qml — which owns the nav bar (Dashboard | Themes |
// Wallpapers | Settings) and the tab-switching content area.
//
// Do NOT put header/nav content here. All visual structure lives in
// ModernDashboard.qml so the tab system stays the single source of truth.
// =============================================================================

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "components" as Components
import "config" as Config

ShellRoot {
    // =========================================================================
    // IPC HANDLER — toggle window visibility from other instances (e.g. bar)
    // =========================================================================
    IpcHandler {
        id: settingsWindowIpc
        target: "SettingsWindow"

        function toggle() {
            panelWindow.visible = !panelWindow.visible
        }

        function show() {
            panelWindow.visible = true
        }

        function hide() {
            panelWindow.visible = false
        }

        // Deep-link to Control tab sections (Quickshell IPC doesn't support
        // arbitrary arguments, so individual functions per section)
        function openControlNetwork() {
            panelWindow.visible = true
            dashboard.openControlTab("network")
        }

        function openControlBluetooth() {
            panelWindow.visible = true
            dashboard.openControlTab("bluetooth")
        }

        function openControlAudio() {
            panelWindow.visible = true
            dashboard.openControlTab("audio")
        }

        function openControlPower() {
            panelWindow.visible = true
            dashboard.openControlTab("power")
        }

        function openControlSystem() {
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
    // PANEL WINDOW — the dashboard overlay
    // =========================================================================
    PanelWindow {
        id: panelWindow

        implicitWidth:  700
        implicitHeight: 650

        // Start hidden — toggled via IPC from the bar
        visible: false

        // Window background — pure black for OLED
        color: Config.SettingsConfig.background

        // =====================================================================
        // MAIN DASHBOARD — owns nav bar + tab content (loaded once, kept alive)
        // =====================================================================
        Components.ModernDashboard {
            id: dashboard
            anchors.fill: parent
        }
    }

    // =========================================================================
    // POWER MENU — full-screen overlay (toggled via the 'powerMenu' IPC target)
    // =========================================================================
    Components.PowerMenu {
        id: powerMenu
    }
}
