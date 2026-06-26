// =============================================================================
// CalendarWidgetCompact.qml — Compact Calendar Widget
// =============================================================================
//
// Smaller OLED-minimal calendar.
// - Day cells: square, zero radius, uniform size
// - Today: small teal underline dot
// - Other-month days: very dim (#2a2a2a)
// - Minimal navigation
//
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

Rectangle {
    id: root

    property int currentMonth: new Date().getMonth()
    property int currentYear:  new Date().getFullYear()
    property int today:        new Date().getDate()

    readonly property var monthNames: [
        "JAN","FEB","MAR","APR","MAY","JUN",
        "JUL","AUG","SEP","OCT","NOV","DEC"
    ]

    readonly property var dayNames: ["S","M","T","W","T","F","S"]

    color:        Config.ThemeConfig.colors.background
    border.color: Config.ThemeConfig.colors.border
    border.width: 1
    radius: 0

    ColumnLayout {
        anchors {
            fill:    parent
            margins: 10
        }
        spacing: 6

        // ── Header: month + nav ─────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text:              `${monthNames[currentMonth]} ${currentYear}`
                font.pixelSize:    9
                font.family:       Config.SettingsConfig.fontFamily
                font.letterSpacing: 1.5
                font.weight:       Font.Medium
                color:             Config.ThemeConfig.colors.text
            }

            Item { Layout.fillWidth: true }

            Item {
                width:  16
                height: 16

                Text {
                    anchors.centerIn: parent
                    text:           "‹"
                    font.pixelSize: 12
                    color:          prevHover.containsMouse ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim

                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                MouseArea {
                    id: prevHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: {
                        if (currentMonth === 0) { currentMonth = 11; currentYear-- }
                        else { currentMonth-- }
                    }
                }
            }

            Item {
                width:  16
                height: 16

                Text {
                    anchors.centerIn: parent
                    text:           "›"
                    font.pixelSize: 12
                    color:          nextHover.containsMouse ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim

                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                MouseArea {
                    id: nextHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: {
                        if (currentMonth === 11) { currentMonth = 0; currentYear++ }
                        else { currentMonth++ }
                    }
                }
            }
        }

        // ── Day-of-week labels ───────────────────────────────────────────────

        GridLayout {
            Layout.fillWidth: true
            columns:      7
            rowSpacing:   0
            columnSpacing: 0

            Repeater {
                model: dayNames

                Text {
                    text:               modelData
                    font.pixelSize:     7
                    font.letterSpacing: 0.8
                    color:              Config.ThemeConfig.colors.textDim
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth:   true
                }
            }
        }

        Item { Layout.preferredHeight: 2 }

        // ── Day grid ─────────────────────────────────────────────────────────

        GridLayout {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            columns:      7
            rowSpacing:   1
            columnSpacing: 1

            Repeater {
                model: getCalendarDays()

                Item {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn: parent
                        text:           modelData.day
                        font.pixelSize: 9
                        font.weight:    modelData.isToday ? Font.Medium : Font.Normal
                        color: {
                            if (modelData.isToday)       return Config.ThemeConfig.colors.text
                            if (modelData.isOtherMonth)  return Config.ThemeConfig.colors.textDim
                            return Config.ThemeConfig.colors.textDim
                        }
                    }

                    Rectangle {
                        visible:         modelData.isToday
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            bottom:           parent.bottom
                            bottomMargin:     1
                        }
                        width:  3
                        height: 2
                        color:  Config.ThemeConfig.colors.secondary
                    }
                }
            }
        }
    }

    function getCalendarDays() {
        const days = []
        const firstDay    = new Date(currentYear, currentMonth, 1)
        const lastDay     = new Date(currentYear, currentMonth + 1, 0)
        const startDay    = firstDay.getDay()
        const totalDays   = lastDay.getDate()
        const prevMonthLast = new Date(currentYear, currentMonth, 0).getDate()
        const todayDate   = new Date()

        for (let i = startDay - 1; i >= 0; i--)
            days.push({ day: prevMonthLast - i, isOtherMonth: true, isToday: false })

        for (let i = 1; i <= totalDays; i++) {
            const isToday = (i === todayDate.getDate() &&
                             currentMonth === todayDate.getMonth() &&
                             currentYear  === todayDate.getFullYear())
            days.push({ day: i, isOtherMonth: false, isToday: isToday })
        }

        const remaining = 42 - days.length
        for (let i = 1; i <= remaining; i++)
            days.push({ day: i, isOtherMonth: true, isToday: false })

        return days
    }
}
