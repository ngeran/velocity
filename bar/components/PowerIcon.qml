// =============================================================================
// PowerIcon.qml — System power menu trigger icon
// =============================================================================
//
// Click to show the power menu (Lock, Suspend, Reboot, Shutdown).
// Matches your existing bar icon aesthetic.
//
// INTERACTIONS:
//   - Click: Toggle power menu visibility
//   - Hover: Color change (follows your existing pattern)
//
// =============================================================================

import QtQuick
import Quickshell.Io
import "../config" as Config

Rectangle {
    id: icon
    objectName: "powerIcon"
    width: Config.BarConfig.iconSize
    height: Config.BarConfig.iconSize
    color: "transparent"

    property bool menuVisible: false

    // Power icon glyph
    Text {
        anchors.centerIn: parent
        text: "󰐦"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        color: mouseArea.containsMouse ? Config.BarConfig.colorAccent : "#ffffff"

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            // Toggle the full-screen PowerMenu overlay (lives in the settings shell)
            toggleProc.running = true
        }
    }

    // IPC call to the settings shell's 'powerMenu' target — same pattern as SettingsIcon
    Process {
        id: toggleProc
        command: ["quickshell", "ipc", "-c", "settings", "call", "powerMenu", "toggle"]
    }
}
