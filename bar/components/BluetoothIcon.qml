// =============================================================================
// BluetoothIcon.qml — Bluetooth status icon
// =============================================================================
//
// Displays Bluetooth adapter power status using Nerd Font icons.
//
// ICONS (nf-md-*)
//   "󰂯" - Bluetooth on (nf-md-bluetooth)
//   "󰂲" - Bluetooth off (nf-md-bluetooth_off)
//
// INTERACTION
//   Click to launch bluetui TUI
// =============================================================================

import QtQuick
import Quickshell.Io
import "../services" as Services
import "../config" as Config

Item {
    id: icon
    width: Config.BarConfig.iconSize
    height: Config.BarConfig.iconSize

    property bool powered: Services.BluetoothService.powered

    Text {
        anchors.centerIn: parent
        text: powered ? "󰂯" : "󰂲"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        color: mouseArea.containsMouse ? Config.BarConfig.colorAccent : (powered ? "#ffffff" : Config.BarConfig.colorTextDim)
        opacity: 1.0
        visible: true

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Component.onCompleted: {
            console.log("[BluetoothIcon] text:", text, "powered:", powered)
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: bluetuiProc.running = true
    }

    Process {
        id: bluetuiProc
        command: ["kitty", "--class=bluetui-float", "bluetui"]
    }
}
