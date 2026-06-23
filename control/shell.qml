// =============================================================================
// shell.qml — Control dashboard entry point (quickshell -c control)
// =============================================================================
//
// Sets up the PanelWindow + ControlWindow IPC handler, then delegates ALL
// layout to ControlDashboard. Mirrors settings/shell.qml.
//
// IPC targets (called from the bar icons + a Hyprland keybind):
//   quickshell ipc -c control call ControlWindow toggle
//   quickshell ipc -c control call ControlWindow open <network|bluetooth|audio|system>
//   quickshell ipc -c control call ControlWindow hide
// =============================================================================

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "components" as Components
import "config" as Config
import "services" as Services

ShellRoot {
    IpcHandler {
        id: controlWindowIpc
        target: "ControlWindow"

        function toggle() {
            panelWindow.visible = !panelWindow.visible
        }

        function open(section: string) {
            panelWindow.visible = true
            if (section !== undefined && section !== "") {
                dashboard.activeSection = section
            }
            dashboard.forceActiveFocus()
        }

        function hide() {
            panelWindow.visible = false
        }

        // Run a curated command as if typed at the prompt (also usable from keybinds).
        function runCommand(cmd: string) {
            panelWindow.visible = true
            Services.CommandService.executeCommand(cmd)
            dashboard.forceActiveFocus()
        }
    }

    PanelWindow {
        id: panelWindow

        implicitWidth: Config.ControlConfig.windowWidth
        implicitHeight: Config.ControlConfig.windowHeight

        // Start hidden — summoned via IPC (exec-once lifecycle, like settings/).
        visible: false

        color: Config.ThemeConfig.colors.background

        Components.ControlDashboard {
            id: dashboard
            anchors.fill: parent
        }
    }
}
