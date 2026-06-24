// =============================================================================
// ClockWidget.qml — Centered clock; click toggles the settings dashboard
// =============================================================================

import QtQuick
import Quickshell.Io
import "../config" as Config

Item {
    id: root
    width: clockText.implicitWidth + 16
    height: clockText.implicitHeight

    function _formattedTime() {
        var d = new Date()
        var h = String(d.getHours()).padStart(2, "0")
        var m = String(d.getMinutes()).padStart(2, "0")
        return h + ":" + m
    }

    Text {
        id: clockText
        anchors.centerIn: parent
        text: root._formattedTime()
        color: clkMa.containsMouse ? Config.BarConfig.colorAccent : Config.BarConfig.colorText
        font.pixelSize: Config.BarConfig.fontSizeClock
        font.family: Config.BarConfig.fontFamily
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: clockText.text = root._formattedTime()
    }

    // Click → toggle the settings dashboard (same target as the gear icon).
    MouseArea {
        id: clkMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: toggleProc.running = true
    }

    Process {
        id: toggleProc
        command: ["quickshell", "ipc", "-c", "settings", "call", "SettingsWindow", "toggle"]
    }
}
