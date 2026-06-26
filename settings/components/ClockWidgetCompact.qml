// =============================================================================
// ClockWidgetCompact.qml — Compact Clock Widget
// =============================================================================
//
// Smaller vertical layout for compact display.
// - Large HH:MM, blinking teal colon
// - Seconds below, dim
// - Date / day-of-week
//
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

Rectangle {
    id: root

    property int    hours:        0
    property int    minutes:      0
    property int    seconds:      0
    property string dayName:      ""
    property string dateString:   ""
    property bool   colonVisible: true

    color:        Config.ThemeConfig.colors.background
    radius:       0

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: updateTime()
    }

    Component.onCompleted: updateTime()

    function updateTime() {
        const now  = new Date()
        hours      = now.getHours()
        minutes    = now.getMinutes()
        seconds    = now.getSeconds()
        colonVisible = !colonVisible

        const days = ["SUN","MON","TUE","WED","THU","FRI","SAT"]
        dayName = days[now.getDay()]

        const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        dateString = `${months[now.getMonth()]} ${now.getDate()}`
    }

    function padZero(n) { return n < 10 ? `0${n}` : `${n}` }

    ColumnLayout {
        anchors { fill: parent; margins: 12 }
        spacing: 0

        // ── HH:MM ───────────────────────────────────────────────────────────────

        Row {
            spacing: 0
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                text:              padZero(hours)
                font.pixelSize:    24
                font.family:       Config.SettingsConfig.fontFamily
                font.weight:       Font.Medium
                font.letterSpacing: -1
                color:             Config.ThemeConfig.colors.text
                lineHeight:        0.95
            }

            Text {
                text:           ":"
                font.pixelSize: 24
                font.family:    Config.SettingsConfig.fontFamily
                font.weight:    Font.Medium
                color:          colonVisible ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border
                lineHeight:     0.95
                Behavior on color { ColorAnimation { duration: 80 } }
            }

            Text {
                text:              padZero(minutes)
                font.pixelSize:    24
                font.family:       Config.SettingsConfig.fontFamily
                font.weight:       Font.Medium
                font.letterSpacing: -1
                color:             Config.ThemeConfig.colors.text
                lineHeight:        0.95
            }
        }

        Item { Layout.preferredHeight: 6 }

        // ── Seconds ─────────────────────────────────────────────────────────────

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:           padZero(seconds)
            font.pixelSize: 12
            font.family:    Config.SettingsConfig.fontFamily
            color:          Config.ThemeConfig.colors.textDim
        }

        Item { Layout.preferredHeight: 8 }

        // ── Divider ───────────────────────────────────────────────────────────

        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.surfaceVariant }

        Item { Layout.preferredHeight: 8 }

        // ── Date ─────────────────────────────────────────────────────────────

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:               dayName
            font.pixelSize:     7
            font.family:        Config.SettingsConfig.fontFamily
            font.letterSpacing: 1.5
            color:              Config.ThemeConfig.colors.textDim
        }

        Item { Layout.preferredHeight: 2 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:               dateString
            font.pixelSize:     8
            font.family:        Config.SettingsConfig.fontFamily
            color:              Config.ThemeConfig.colors.textDim
        }

        Item { Layout.fillHeight: true }
    }
}
