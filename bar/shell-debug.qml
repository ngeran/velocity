// =============================================================================
// shell.qml — QuickShell bar entry point (DEBUG VERSION)
// =============================================================================
//
// Minimal bar shell to debug crash
//
// =============================================================================

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "components" as Components
import "config" as Config

ShellRoot {
    PanelWindow {
        id: panelWindow

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: 26
        color: "#000000"

        // Minimal bar - just one text element for testing
        Text {
            anchors.centerIn: parent
            text: "TEST BAR"
            color: "#ffffff"
            font.pixelSize: 12
        }
    }

    // IPC handler for testing
    IpcHandler {
        id: barToggleIpc
        target: "barToggle"

        function toggle() {
            console.log("[Bar] Toggle called - bar is visible")
        }
    }
}
