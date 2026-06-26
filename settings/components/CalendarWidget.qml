// =============================================================================
// CalendarWidget.qml — Calendar for the dashboard bento grid
// =============================================================================
// Header · Month/Year title + today badge · day-of-week · date grid (today
// accent-filled, weekends dimmed).
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "." as Components

Item {
    id: calRoot

    // -------------------------------------------------------------------------
    // DATE STATE
    // -------------------------------------------------------------------------
    property var    _today:        new Date()
    property int    _todayDay:     _today.getDate()
    property int    _todayMonth:   _today.getMonth()
    property int    _todayYear:    _today.getFullYear()
    property var    _firstOfMonth: new Date(_todayYear, _todayMonth, 1)
    property int    _startOffset:  _firstOfMonth.getDay()
    property int    _daysInMonth:  new Date(_todayYear, _todayMonth + 1, 0).getDate()
    property int    _cellCount:    _startOffset + _daysInMonth
    property string _monthLabel:   Qt.formatDateTime(_today, "MMMM").toUpperCase()
    property string _yearLabel:    Qt.formatDateTime(_today, "yyyy")

    Timer {
        interval: 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: calRoot._today = new Date()
    }

    // -------------------------------------------------------------------------
    // LAYOUT
    // -------------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Components.WidgetHeader {
            icon: "󰃭"
            label: "CALENDAR"
            Layout.bottomMargin: 10
        }

        // Month/Year title + today badge
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 10

            Text {
                text: calRoot._monthLabel
                color: Config.ThemeConfig.colors.primary
                font.pixelSize: 16; font.bold: true
                font.family: Config.SettingsConfig.fontFamily
                font.letterSpacing: 2.0
            }
            Text {
                text: " " + calRoot._yearLabel
                color: Config.ThemeConfig.colors.textDim
                font.pixelSize: 16
                font.family: Config.SettingsConfig.fontFamily
                font.letterSpacing: 1.5
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 52; height: 20
                color: Config.ThemeConfig.colors.secondary
                Text {
                    anchors.centerIn: parent
                    text: "TODAY " + calRoot._todayDay
                    color: Config.ThemeConfig.colors.background
                    font.pixelSize: 9; font.bold: true
                    font.family: Config.SettingsConfig.fontFamily
                    font.letterSpacing: 1.0
                }
            }
        }

        // Day-of-week header
        GridLayout {
            Layout.fillWidth: true
            columns: 7
            columnSpacing: 3
            rowSpacing: 0
            Layout.bottomMargin: 4

            Repeater {
                model: ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
                delegate: Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: (index === 0 || index === 6)
                           ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.textDim, 0.6)
                           : Config.ThemeConfig.colors.textDim
                    font.pixelSize: 9; font.bold: true
                    font.family: Config.SettingsConfig.fontFamily
                    font.letterSpacing: 0.5
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Config.ThemeConfig.colors.outlineVariant
            Layout.bottomMargin: 4
        }

        // Date grid
        GridLayout {
            id: calGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            columnSpacing: 3
            rowSpacing: 3

            Repeater {
                model: calRoot._cellCount

                delegate: Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    readonly property int  dayNumber: (index < calRoot._startOffset) ? 0 : (index - calRoot._startOffset + 1)
                    readonly property bool isToday:   dayNumber === calRoot._todayDay
                    readonly property bool isBlank:   dayNumber === 0
                    readonly property bool isWeekend: (index % 7 === 0) || (index % 7 === 6)

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - 2
                        height: width
                        color: parent.isToday ? Config.ThemeConfig.colors.secondary : "transparent"
                        visible: !parent.isBlank
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !parent.isBlank
                        text: parent.dayNumber.toString()
                        color: parent.isToday
                               ? Config.ThemeConfig.colors.background
                               : parent.isWeekend
                                 ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.textDim, 0.6)
                                 : Config.ThemeConfig.colors.text
                        font.pixelSize: 11; font.bold: parent.isToday
                        font.family: Config.SettingsConfig.fontFamily
                    }
                }
            }
        }
    }
}
