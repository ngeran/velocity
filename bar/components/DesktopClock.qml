// =============================================================================
// DesktopClock.qml — Enhanced Desktop Clock Widget
// =============================================================================
//
// Adds a desktop clock with configurable positioning
//
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

Item {
    id: root

    // Scale (0.5 to 2.0)
    property real clockScale: 1.0

    // Enable/disable features
    property bool showDate: true
    property bool showSeconds: false

    // 12/24 hour format
    property bool use24Hour: true

    // Color theme
    property string colorTheme: "auto"

    // Current time data
    property var currentTime: new Date()

    // Primary color based on theme brightness
    readonly property color primaryColor: {
        if (colorTheme === "light") return "#000000"
        if (colorTheme === "dark") return "#ffffff"
        // Auto: determine based on theme
        var bg = Config.ThemeConfig.colors.background
        var r = parseInt(bg.substring(1, 3), 16)
        var g = parseInt(bg.substring(3, 5), 16)
        var b = parseInt(bg.substring(5, 7), 16)
        var brightness = (r * 0.299 + g * 0.587 + b * 0.114)
        return brightness > 128 ? "#000000" : "#ffffff"
    }

    // Secondary color
    readonly property color secondaryColor: {
        if (colorTheme === "light") return "#666666"
        if (colorTheme === "dark") return "#aaaaaa"
        var bg = Config.ThemeConfig.colors.background
        var r = parseInt(bg.substring(1, 3), 16)
        var g = parseInt(bg.substring(3, 5), 16)
        var b = parseInt(bg.substring(5, 7), 16)
        var brightness = (r * 0.299 + g * 0.587 + b * 0.114)
        return brightness > 128 ? "#666666" : "#aaaaaa"
    }

    implicitWidth: clockLayout.implicitWidth * clockScale + 32
    implicitHeight: clockLayout.implicitHeight * clockScale + 32

    // Background panel
    Rectangle {
        id: background
        anchors.fill: parent
        radius: 12
        color: Config.ThemeConfig.colors.surface
        opacity: 0.8
        border.color: Config.ThemeConfig.colors.border
        border.width: 1
    }

    // Clock content
    RowLayout {
        id: clockLayout
        anchors.centerIn: parent
        spacing: 12 * clockScale

        // Time column
        Column {
            spacing: 2

            Text {
                text: {
                    var hours = currentTime.getHours()
                    var minutes = currentTime.getMinutes()
                    var ampm = ""
                    if (!root.use24Hour) {
                        ampm = hours >= 12 ? " PM" : " AM"
                        hours = hours % 12
                        if (hours === 0) hours = 12
                    }
                    var hStr = hours < 10 ? "0" + hours : hours
                    var mStr = minutes < 10 ? "0" + minutes : minutes
                    return hStr + ":" + mStr + ampm
                }
                font.pixelSize: 48 * clockScale
                font.family: "monospace"
                font.bold: true
                color: primaryColor
            }

            Text {
                text: {
                    var seconds = currentTime.getSeconds()
                    return seconds < 10 ? "0" + seconds : seconds
                }
                font.pixelSize: 18 * clockScale
                font.family: "monospace"
                color: secondaryColor
                visible: root.showSeconds
                anchors.right: parent.right
            }
        }

        // Date column
        Column {
            spacing: 2
            visible: root.showDate

            Text {
                text: {
                    var days = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
                    return days[currentTime.getDay()]
                }
                font.pixelSize: 10 * clockScale
                font.family: "monospace"
                font.letterSpacing: 1.5
                color: secondaryColor
            }

            Text {
                text: {
                    var months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
                    var month = months[currentTime.getMonth()]
                    var day = currentTime.getDate()
                    var dayStr = day < 10 ? "0" + day : day
                    return month + " " + dayStr
                }
                font.pixelSize: 18 * clockScale
                font.family: "monospace"
                font.bold: true
                color: primaryColor
            }
        }
    }

    // Update timer
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.currentTime = new Date()
        }
    }

    Component.onCompleted: {
        console.log("[DesktopClock] Desktop Clock loaded")
    }
}
