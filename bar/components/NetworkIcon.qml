// =============================================================================
// NetworkIcon.qml — Network status icon
// =============================================================================

import QtQuick
import Quickshell.Io
import "../services" as Services
import "../config" as Config

Rectangle {
    id: icon
    width: Config.BarConfig.iconSize
    height: Config.BarConfig.iconSize
    color: "transparent"

    property bool isConnected: Services.NetworkService.isConnected
    property string connectionType: Services.NetworkService.connectionType

    Text {
        anchors.centerIn: parent
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

        Component.onCompleted: {
            console.log("[NetworkIcon] text:", text, "isConnected:", icon.isConnected)
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
    }

    Process {
        id: netProc
        command: ["kitty", "--class=impala-float", "impala"]
    }
}
