// =============================================================================
// components/CalendarWidget.qml — Full-Bleed Bento Calendar
// VERSION: V2.0
//
// FIXES vs V1:
//   - Root is Item, not ColumnLayout — parent controls size, not children
//   - Cells use Layout.fillWidth/fillHeight so grid expands to fill the card
//   - Typography scaled up: month label 13px, day letters 10px, day numbers 13px
//   - Today chip: theme accent (secondary) bg + background text, sharp corners (radius:0)
//   - Weekend columns (Sun/Sat) dimmed differently from weekdays
//   - Divider replaced with spacing for cleaner look
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

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
    // LAYOUT — ColumnLayout as child, fills the Item
    // -------------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── HEADER ────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth:    true
            Layout.bottomMargin: 10

            Text {
                text:               calRoot._monthLabel
                color:              Config.ThemeConfig.colors.primary
                font.pixelSize:     13
                font.bold:          true
                font.family:        Config.SettingsConfig.fontFamily
                font.letterSpacing: 2.5
            }

            Text {
                text:               " " + calRoot._yearLabel
                color:              Config.ThemeConfig.colors.textDim
                font.pixelSize:     13
                font.family:        Config.SettingsConfig.fontFamily
                font.letterSpacing: 1.5
            }

            Item { Layout.fillWidth: true }

            // Today badge — teal pill with day number
            Rectangle {
                width:  48
                height: 20
                color:  Config.ThemeConfig.colors.secondary
                radius: 0

                Text {
                    anchors.centerIn: parent
                    text:             "TODAY " + calRoot._todayDay
                    color:            Config.ThemeConfig.colors.background
                    font.pixelSize:   9
                    font.bold:        true
                    font.family:      Config.SettingsConfig.fontFamily
                    font.letterSpacing: 1.0
                }
            }
        }

        // ── DAY-OF-WEEK HEADER ────────────────────────────────────────────────
        GridLayout {
            Layout.fillWidth: true
            columns:          7
            columnSpacing:    3
            rowSpacing:       0
            Layout.bottomMargin: 4

            Repeater {
                model: ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
                delegate: Text {
                    Layout.fillWidth:   true
                    Layout.alignment:   Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                    text:               modelData
                    // Weekends (index 0, 6) dimmer
                    color:              (index === 0 || index === 6)
                                        ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.textDim, 0.6)
                                        : Config.ThemeConfig.colors.textDim
                    font.pixelSize:     9
                    font.bold:          true
                    font.family:        Config.SettingsConfig.fontFamily
                    font.letterSpacing: 0.5
                }
            }
        }

        // Separator
        Rectangle {
            Layout.fillWidth:    true
            height:              1
            color:               Config.ThemeConfig.colors.outlineVariant
            Layout.bottomMargin: 4
        }

        // ── CALENDAR GRID ─────────────────────────────────────────────────────
        GridLayout {
            id: calGrid
            Layout.fillWidth:  true
            Layout.fillHeight: true
            columns:           7
            columnSpacing:     3
            rowSpacing:        3

            Repeater {
                model: calRoot._cellCount

                delegate: Item {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true

                    readonly property int  dayNumber: (index < calRoot._startOffset) ? 0 : (index - calRoot._startOffset + 1)
                    readonly property bool isToday:   dayNumber === calRoot._todayDay
                    readonly property bool isBlank:   dayNumber === 0
                    // Weekend column: col = index % 7
                    readonly property bool isWeekend: (index % 7 === 0) || (index % 7 === 6)

                    // Today highlight
                    Rectangle {
                        anchors.centerIn: parent
                        width:   Math.min(parent.width, parent.height) - 2
                        height:  width
                        radius:  0
                        color:   parent.isToday ? Config.ThemeConfig.colors.secondary : "transparent"
                        visible: !parent.isBlank
                    }

                    Text {
                        anchors.centerIn: parent
                        visible:          !parent.isBlank
                        text:             parent.dayNumber.toString()
                        color:            parent.isToday
                                          ? Config.ThemeConfig.colors.background
                                          : parent.isWeekend
                                            ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.textDim, 0.6)
                                            : Config.ThemeConfig.colors.textDim
                        font.pixelSize:   11
                        font.bold:        parent.isToday
                        font.family:      Config.SettingsConfig.fontFamily
                    }
                }
            }
        }
    }
}
