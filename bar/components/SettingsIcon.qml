// =============================================================================
// SettingsIcon.qml — Settings toggle icon
// =============================================================================
//
// Click to toggle the QuickShell settings window visibility via IPC.
//
// =============================================================================

import QtQuick
import Quickshell.Io
import "../config" as Config

Rectangle {
    id: icon
    width: Config.BarConfig.iconSize
    height: Config.BarConfig.iconSize
    color: "transparent"

    Text {
        anchors.centerIn: parent
        text: "󰒓"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        color: mouseArea.containsMouse ? Config.BarConfig.colorAccent : "#ffffff"

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Component.onCompleted: {
            console.log("[SettingsIcon] Gear icon loaded - position:", parent.x, parent.y)
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            console.log("[SettingsIcon] Clicked! Running IPC command...")
            // Send IPC call to toggle settings window
            toggleProc.running = true
        }
    }

    Process {
        id: toggleProc
        command: ["quickshell", "ipc", "-c", "settings", "call", "SettingsWindow", "toggle"]

        onRunningChanged: {
            console.log("[SettingsIcon] IPC process running:", running)
        }

        onExited: function(exitCode) {
            console.log("[SettingsIcon] IPC process exited with code:", exitCode)
        }
    }
}
