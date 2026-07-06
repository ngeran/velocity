// =============================================================================
// ArchLogo.qml — Arch Linux icon with fastfetch action
// =============================================================================

import QtQuick
import Quickshell.Io
import "../config" as Config

Item {
    id: icon
    width: Config.BarConfig.iconSize
    height: Config.BarConfig.iconSize

    // Custom Arch Linux SVG
    Image {
        id: archSvg
        anchors.centerIn: parent
        width: 15
        height: 15
        
        // We use standard string concatenation to ensure the SVG is built correctly
        source: "data:image/svg+xml;base64," + Qt.btoa(
            '<svg width="24" height="25" viewBox="0 0 24 25" fill="none" xmlns="http://www.w3.org/2000/svg">' +
            '<path d="M15.7733 10.2843L23.998 2.05957L22.1477 0.20926L13.923 8.43396L15.7733 10.2843Z" fill="' + (mouseArea.containsMouse ? Config.BarConfig.colorAccent : Config.ThemeConfig.colors.text) + '"/>' +
            '<path d="M0.00772348 2.06143L8.23242 10.2861L10.0827 8.43582L1.85803 0.211124L0.00772348 2.06143Z" fill="' + (mouseArea.containsMouse ? Config.BarConfig.colorAccent : Config.ThemeConfig.colors.text) + '"/>' +
            '<path d="M24.0001 22.3468L15.7754 14.1221L13.9251 15.9724L22.1498 24.1971L24.0001 22.3468Z" fill="' + (mouseArea.containsMouse ? Config.BarConfig.colorAccent : Config.ThemeConfig.colors.text) + '"/>' +
            '<path d="M8.2247 14.1249L0 22.3496L1.85031 24.1999L10.075 15.9752L8.2247 14.1249Z" fill="' + (mouseArea.containsMouse ? Config.BarConfig.colorAccent : Config.ThemeConfig.colors.text) + '"/>' +
            '</svg>'
        )
        smooth: true
        mipmap: true
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            // Robust toggle: Simply flip the running state
            fastfetchProc.running = !fastfetchProc.running
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
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    Process {
        id: fastfetchProc
        command: [
            "kitty",
            "--class", "fastfetch-float",
            "--title", "System Info",
            
            // UI Tweaks
            "-o", "shell_integration=disabled",
            "-o", "window_padding_width=25",
            "-o", "confirm_os_window_close=0",
            "-o", "cursor_blink_interval=0",
            
            // Call the wrapper instead of fastfetch directly
            "bash", "/home/nikos/.config/hypr/scripts/fastfetch_wrapper.sh"
        ]
    } 
}
