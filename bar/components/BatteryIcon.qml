// =============================================================================
// BatteryIcon.qml — Battery status indicator with shell-level hover popup
// =============================================================================
//
// Displays battery charge level and charging status using Nerd Font icons.
//
// ICONS (nf-md-*)
//   "󰂄" - Battery + charging indicator
//   "󰁹" - Battery (discharging)
// Changes color based on charge level
//
// INTERACTION
//   Hover to show battery info popup
// =============================================================================

import QtQuick
import Quickshell.Io
import "../services" as Services
import "../config" as Config

Item {
    id: icon
    width: Config.BarConfig.iconSize
    height: Config.BarConfig.iconSize
    objectName: "batteryIcon"

    property int percentage: Services.BatteryService.percentage
    property bool charging: Services.BatteryService.charging
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
            console.log("[BatteryIcon] Could not find ShellRoot!")
        }
        console.log("[BatteryIcon] percentage:", percentage, "charging:", charging)
    }

    Row {
        anchors.centerIn: parent
        spacing: 4

        Text {
            // Battery icon glyph
            text: icon.charging ? "󰂄" : "󰁹"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: mouseArea.containsMouse ? Config.BarConfig.colorAccent : icon._batteryColor()
            opacity: 1.0
            visible: true

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
            // Optional: Click could toggle a more detailed view or open a battery tool
        }

        onEntered: {
            if (icon.shellRoot) {
                // Get the icon's position relative to the shell (screen coordinates)
                var pos = icon.parent.mapToItem(icon.shellRoot, icon.x, icon.y)
                var timeEstimate = icon.charging ? "Charging" : "Discharging"
                icon.shellRoot.hoverPopupData = {
                    visible: true,
                    text: "Battery",
                    subtext: icon.percentage + "%" + (icon.charging ? " ⚡" : ""),
                    details: [
                        timeEstimate,
                        icon.percentage <= 20 ? "⚠️ Low battery" : ""
                    ].filter(function(d) { return d !== "" }),
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

    function _batteryColor() {
        if (icon.charging) return "#68d391"  // Green when charging
        if (icon.percentage <= 20) return "#f87171"  // Red when low
        if (icon.percentage <= 50) return "#fbbf24"  // Yellow at half
        return "#ffffff"  // White otherwise
    }
}
