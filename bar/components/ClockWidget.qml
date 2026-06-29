// =============================================================================
// ClockWidget.qml — Centered clock + date; click toggles the settings dashboard
// =============================================================================

import QtQuick
import Quickshell.Io
import "../config" as Config

Item {
    id: root
    width: Math.max(clockText.implicitWidth, dateText.implicitWidth) + 16
    height: clockText.implicitHeight + dateText.implicitHeight + 2

    readonly property var _days:   ["SUN","MON","TUE","WED","THU","FRI","SAT"]
    readonly property var _months: ["JAN","FEB","MAR","APR","MAY","JUN",
                                    "JUL","AUG","SEP","OCT","NOV","DEC"]

    function _formattedTime() {
        var d = new Date()
        var h = String(d.getHours()).padStart(2, "0")
        var m = String(d.getMinutes()).padStart(2, "0")
        return h + ":" + m
    }

    // e.g.  "MON · 29 JUN"
    function _formattedDate() {
        var d   = new Date()
        var day = _days[d.getDay()]
        var num = String(d.getDate()).padStart(2, "0")
        var mon = _months[d.getMonth()]
        return day + " · " + num + " " + mon
    }

    Column {
        anchors.centerIn: parent
        spacing: -1

        Text {
            id: clockText
            anchors.horizontalCenter: parent.horizontalCenter
            text: root._formattedTime()
            color: clkMa.containsMouse ? Config.BarConfig.colorAccent : Config.BarConfig.colorText
            font.pixelSize: Config.BarConfig.fontSizeClock
            font.family: Config.BarConfig.fontFamily
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            text: root._formattedDate()
            color: clkMa.containsMouse
                   ? Qt.rgba(0, 0.863, 0.898, 0.65)   // teal @ 65 % on hover
                   : Qt.rgba(1, 1, 1, 0.30)             // #ffffff @ 30 % at rest
            font.pixelSize: 9
            font.family: Config.BarConfig.fontFamily
            font.weight: Font.Bold
            font.letterSpacing: 2.5
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            clockText.text = root._formattedTime()
            dateText.text  = root._formattedDate()
        }
    }

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
