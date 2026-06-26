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
            }

            Components.BluetoothIcon {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 2
            }

            Components.VolumeIcon {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 2
            }

            Components.BatteryIcon {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 2
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
}
