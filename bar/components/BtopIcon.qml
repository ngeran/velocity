// =============================================================================
// BtopIcon.qml — bar trigger that opens the native System Monitor overlay
// =============================================================================
// Clicking fires a one-shot Quickshell IPC call that toggles the settings
// process's SystemMonitorOverlay (a themed, realtime btop replacement — see
// settings/components/SystemMonitorOverlay.qml). Closes via Esc / click-outside.
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
        onClicked: btopProc.running = true
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
        // One-shot IPC toggle into the settings process's SystemMonitorOverlay.
        command: ["quickshell", "ipc", "-c", "settings", "call", "systemMonitor", "toggle"]
    }
}
