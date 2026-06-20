// =============================================================================
// BatteryIcon.qml — Battery status indicator with popup
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
//   Click to show battery info popup
// =============================================================================

import QtQuick
import Quickshell.Io
import "../services" as Services
import "../config" as Config

Item {
    id: icon
    width: Config.BarConfig.iconSize
    height: Config.BarConfig.iconSize

    property int percentage: Services.BatteryService.percentage
    property bool charging: Services.BatteryService.charging
    property bool popupVisible: false

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
            console.log("[BatteryIcon] Clicked! popupVisible:", icon.popupVisible)
            icon.popupVisible = !icon.popupVisible
            console.log("[BatteryIcon] After toggle popupVisible:", icon.popupVisible)
        }
    }

    // Battery Info Popup (custom Item-based popup)
    Item {
        id: batteryPopup
        parent: icon  // Set parent explicitly

        visible: icon.popupVisible
        x: icon.width / 2 - 100  // width/2 centered
        y: icon.height + 8

        width: 200
        height: 120

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            border.color: Config.BarConfig.colorAccent
            border.width: 1
            radius: 8

            // Fade in/out animation
            opacity: icon.popupVisible ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }
        }

        Column {
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 8

            Text {
                text: "Battery Status"
                font.family: "JetBrains Mono"
                font.pixelSize: 14
                font.bold: true
                color: "#ffffff"
            }

            Text {
                text: icon.percentage + "% Charged"
                font.family: "JetBrains Mono"
                font.pixelSize: 16
                color: icon._batteryColor()
            }

            Text {
                text: icon.charging ? "⚡ Charging" : "🔋 Discharging"
                font.family: "JetBrains Mono"
                font.pixelSize: 12
                color: "#ffffff"
            }

            // Battery level bar
            Rectangle {
                width: parent.width
                height: 8
                radius: 4
                color: "#333333"

                Rectangle {
                    width: parent.width * (icon.percentage / 100)
                    height: parent.height
                    radius: 4
                    color: icon._batteryColor()

                    Behavior on width {
                        NumberAnimation { duration: 300 }
                    }
                }
            }
        }

        // Close popup when clicking outside
        MouseArea {
            anchors.fill: parent
            onClicked: {
                console.log("[BatteryIcon] Popup clicked, closing...")
                icon.popupVisible = false
            }
        }
    }

    Component.onCompleted: {
        console.log("[BatteryIcon] percentage:", percentage, "charging:", charging)
    }

    function _batteryColor() {
        if (icon.charging) return "#ffffff"
        if (icon.percentage <= 20) return "#f87171"
        if (icon.percentage <= 50) return "#fbbf24"
        return "#ffffff"
    }
}
