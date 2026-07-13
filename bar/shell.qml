// =============================================================================
// shell.qml — Quickshell bar entry point
// =============================================================================
//
// This is the main entry point for Quickshell. It creates a panel window
// and arranges all UI components.
//
// LAYOUT
//   Left & Right: Handled inside the RowLayout flow.
//   Center: Clock is absolute-positioned relative to the window parent,
//           guaranteeing perfect mathematical centering on your screen.
//
// CUSTOMIZATION
//   All colors and sizes are configured in config/BarConfig.qml
// =============================================================================

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "components" as Components
import "config" as Config

ShellRoot {
    PanelWindow {
        id: panelWindow

        property string activeTray: ""   // "network" | "bluetooth" | "volume" | "power" | "" (closed)

        // =========================================================================
        // POSITIONING
        // =========================================================================

        anchors {
            top: true
            left: true
            right: true
        }

        // =========================================================================
        // APPEARANCE (from config)
        // =========================================================================

        implicitHeight: Config.BarConfig.barHeight
        color: Config.BarConfig.colorBackground

        // =========================================================================
        // MAIN LAYOUT (Left and Right Sections)
        // =========================================================================

        // Click on empty bar area closes the open tray card.
        MouseArea {
            anchors.fill: parent
            enabled: panelWindow.activeTray !== ""
            onClicked: panelWindow.activeTray = ""
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // --- LEFT SIDE ---

            Components.ArchLogo {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: Config.BarConfig.barPadding
            }

            Components.WorkspaceWidget {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: Config.BarConfig.iconSpacing
            }

            // --- HUGE MIDDLE GAP ---
            // This spacer now pushes everything else all the way to the right side
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            // --- RIGHT SIDE ---

            Components.NetworkIcon {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 2
                isActive: panelWindow.activeTray === "network"
                onTrayRequested: panelWindow.activeTray = panelWindow.activeTray === "network" ? "" : "network"
            }

            Components.BluetoothIcon {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 2
                isActive: panelWindow.activeTray === "bluetooth"
                onTrayRequested: panelWindow.activeTray = panelWindow.activeTray === "bluetooth" ? "" : "bluetooth"
            }

            Components.VolumeIcon {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 2
                isActive: panelWindow.activeTray === "volume"
                onTrayRequested: panelWindow.activeTray = panelWindow.activeTray === "volume" ? "" : "volume"
            }

            Components.BatteryIcon {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 2
                isActive: panelWindow.activeTray === "power"  // Changed from "battery" to "power"
                onTrayRequested: panelWindow.activeTray = panelWindow.activeTray === "power" ? "" : "power"  // Changed from "battery" to "power"
            }

            Components.BtopIcon {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 2
            }

            Components.NotificationButton {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 2
                isActive: notificationCenter.shown
                onCenterRequested: notificationCenter.toggle()
            }

            Item {
                width: Config.BarConfig.barPadding
                Layout.fillHeight: true
            }
        }

        // =========================================================================
        // PERFECTLY CENTERED CLOCK
        // =========================================================================
        // Sitting outside the RowLayout, this anchors directly to the panel window.
        // It will remain dead-center even if you delete all icons on the right.

        Components.ClockWidget {
            anchors.centerIn: parent
        }
    }

    // =========================================================================
    // SHARED TRAY CARD — dropdown for Network/Bluetooth/Volume/Power
    // =========================================================================
    Components.TrayCard {
        activeTray: panelWindow.activeTray
        onCloseRequested: panelWindow.activeTray = ""
    }

    // =========================================================================
    // NOTIFICATION CENTER — slide-in panel (toggled by NotificationButton)
    // =========================================================================
    Components.NotificationCenter {
        id: notificationCenter
    }

    // =========================================================================
    // KEYBINDS OVERLAY — mod+K cheat-sheet (toggled via IPC)
    // =========================================================================
    Components.KeybindsOverlay {
        id: keybindsOverlay
    }

    // =========================================================================
    // IPC HANDLERS — External Control
    // =========================================================================

    // Bar visibility toggle (for Hyprland keybind)
    IpcHandler {
        id: barToggleIpc
        target: "barToggle"

        function toggle() {
            panelWindow.visible = !panelWindow.visible
            console.log("[Bar] Visibility toggled:", panelWindow.visible)
        }
    }

    // Keybinds overlay toggle (for SUPER+K — see configs/hypr/keybindings.lua)
    IpcHandler {
        id: keybindsIpc
        target: "keybinds"

        function toggle() {
            keybindsOverlay.toggle()
        }
    }
}
