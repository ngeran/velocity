// =============================================================================
// BluetoothIcon.qml — Bluetooth status icon with shell-level hover popup
// =============================================================================

import QtQuick
import Quickshell.Io
import "../services" as Services
import "../config" as Config

Item {
    id: icon
    width: Config.BarConfig.iconSize
    height: Config.BarConfig.iconSize
    objectName: "bluetoothIcon"

    property bool powered: Services.BluetoothService.powered
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
            console.log("[BluetoothIcon] Could not find ShellRoot!")
        }
    }

    Text {
        anchors.centerIn: parent
        text: powered ? "󰂯" : "󰂲"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        color: mouseArea.containsMouse ? Config.BarConfig.colorAccent : (powered ? "#ffffff" : Config.BarConfig.colorTextDim)

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: bluetuiProc.running = true

        onEntered: {
            if (icon.shellRoot) {
                // Get the icon's position relative to the shell (screen coordinates)
                var pos = icon.parent.mapToItem(icon.shellRoot, icon.x, icon.y)
                icon.shellRoot.hoverPopupData = {
                    visible: true,
                    text: "Bluetooth",
                    subtext: powered ? "Powered On" : "Powered Off",
                    details: ["Click to open control"],
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
        id: bluetuiProc
        command: ["quickshell", "ipc", "-c", "control", "call", "ControlWindow", "open", "bluetooth"]
    }
}
