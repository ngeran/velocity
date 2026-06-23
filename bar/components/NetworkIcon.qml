// =============================================================================
// NetworkIcon.qml — Network status icon with shell-level hover popup
// =============================================================================

import QtQuick
import Quickshell.Io
import "../services" as Services
import "../config" as Config

Item {
    id: icon
    width: Config.BarConfig.iconSize
    height: Config.BarConfig.iconSize
    objectName: "networkIcon"

    property bool isConnected: Services.NetworkService.isConnected
    property string connectionType: Services.NetworkService.connectionType

    // Get shell root access for hover popup
    property var shellRoot: null

    Component.onCompleted: {
        // Find ShellRoot by traversing up the parent hierarchy
        function findShellRoot(item) {
            if (!item) return null
            // Check if this item has the hoverPopupData property (ShellRoot marker)
            if (item.hoverPopupData !== undefined) return item
            if (item.parent) return findShellRoot(item.parent)
            return null
        }
        shellRoot = findShellRoot(icon.parent)
        if (!shellRoot) {
            console.log("[NetworkIcon] Could not find ShellRoot!")
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: {
                if (!icon.isConnected) return "󰖪"
                if (icon.connectionType === "wifi") return "󰖩"
                if (icon.connectionType === "ethernet") return "󰈀"
                return "󰖩"
            }
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: mouseArea.containsMouse ? Config.BarConfig.colorAccent : (icon.isConnected ? "#ffffff" : "#f87171")

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            netProc.running = true
        }

        onEntered: {
            if (icon.shellRoot) {
                // Get the icon's position relative to the shell (screen coordinates)
                var pos = icon.parent.mapToItem(icon.shellRoot, icon.x, icon.y)
                icon.shellRoot.hoverPopupData = {
                    visible: true,
                    text: "Network Status",
                    subtext: icon.isConnected ? "Connected" : "Disconnected",
                    details: icon.isConnected ? ["Type: " + icon.connectionType.toUpperCase()] : ["No connection"],
                    x: pos.x + icon.width/2 - 60,  // Center the popup horizontally
                    y: pos.y  // Icon's Y position (popup adds bar offset)
                }
            }
        }

        onExited: {
            if (icon.shellRoot) {
                icon.shellRoot.hoverPopupData.visible = false
            }
        }
    }

    Process {
        id: netProc
        command: ["quickshell", "ipc", "-c", "control", "call", "ControlWindow", "open", "network"]
    }
}
