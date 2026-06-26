// =============================================================================
// ArchLogo.qml — Arch Linux icon with fastfetch action
// =============================================================================
//
// Displays the Arch Linux Nerd Font icon (󰣇) in the bar.
//
// INTERACTION
//   Click to launch fastfetch in a centered floating kitty window
// =============================================================================

import QtQuick
import Quickshell.Io
import "../config" as Config

Item {
    id: icon
    width: Config.BarConfig.iconSize
    height: Config.BarConfig.iconSize

    Text {
        anchors.centerIn: parent
        text: "󰣇"
        font.family: Config.BarConfig.fontNerd
        font.pixelSize: 16
        color: mouseArea.containsMouse ? Config.BarConfig.colorAccent : Config.ThemeConfig.colors.text

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
            fastfetchProc.running = true
        }
    }

    // Tooltip on hover
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 4
        text: "System Info"
        font.family: Config.BarConfig.fontFamily
        font.pixelSize: 10
        color: Config.ThemeConfig.colors.textDim
        visible: mouseArea.containsMouse

        opacity: mouseArea.containsMouse ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }
    }

    Process {
        id: fastfetchProc
        // Launch fastfetch in a centered floating kitty window
        command: [
            "kitty",
            "--class=fastfetch-float",
            "--title=fastfetch",
            "-o",
            "font_size=14",
            "-o",
            "background_opacity=0.9",
            "--hold",
            "fastfetch"
        ]
    }
}
