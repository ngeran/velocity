// =============================================================================
// BtopIcon.qml — bar trigger that reveals btop in a centered floating window
// =============================================================================
// Mirrors ArchLogo.qml's fastfetch pattern: clicking toggles a kitty window of
// class "btop-float", which a Hyprland rule (configs/hypr/rules.lua) centers and
// sizes to a fixed 1000x700. Click again (or press 'q' inside btop) to close.
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
        text: String.fromCodePoint(0xf0128)   // nf-md-chart_bar (btop = bar charts)
        font.family: Config.BarConfig.fontNerd
        font.pixelSize: 15
        color: mouseArea.containsMouse ? Config.BarConfig.colorAccent : Config.ThemeConfig.colors.text
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btopProc.running = !btopProc.running
    }

    // Tooltip on hover
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 4
        text: "btop"
        font.family: Config.BarConfig.fontFamily
        font.pixelSize: 10
        color: Config.ThemeConfig.colors.textDim
        visible: mouseArea.containsMouse
        opacity: mouseArea.containsMouse ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    Process {
        id: btopProc
        command: [
            "kitty",
            "--class", "btop-float",
            "--title", "btop",
            "-o", "shell_integration=disabled",
            "-o", "window_padding_width=10",
            "-o", "confirm_os_window_close=0",
            "-o", "cursor_blink_interval=0",
            "btop"
        ]
    }
}
