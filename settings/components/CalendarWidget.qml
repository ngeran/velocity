// =============================================================================
// components/CalendarWidget.qml
// Monthly Calendar Grid — Auto-generated from current system date
//
// USAGE:
//   UI.CalendarWidget {
//       anchors.fill: parent
//       anchors.margins: 24
//   }
//
// SELF-CONTAINED: Derives current month/year/today from system clock.
//                 No external bindings or props required (fully autonomous).
//
// GRID LOGIC:
//   1. Determine the weekday offset of the 1st of the month (0=Sun … 6=Sat)
//   2. Repeater model = offset blank cells + day cells = offset + daysInMonth
//   3. Day cell index relative to content:  (index - offset + 1)
//   4. Today highlighted with primary background + dark text (inverted chip)
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

ColumnLayout {
    id: calRoot

    spacing: 0

    // -------------------------------------------------------------------------
    // DERIVED DATE STATE — recalculated once on component load
    // (For a live refresh at midnight, wrap in a Timer that resets _today.)
    // -------------------------------------------------------------------------
    property var    _today:       new Date()
    property int    _todayDay:    _today.getDate()
    property int    _todayMonth:  _today.getMonth()
    property int    _todayYear:   _today.getFullYear()

    // First day of the current month (used to compute weekday offset)
    property var    _firstOfMonth: new Date(_todayYear, _todayMonth, 1)

    // getDay() returns 0=Sun, 1=Mon … 6=Sat — matches our "S M T W T F S" header
    property int    _startOffset:  _firstOfMonth.getDay()

    // Days in current month: day 0 of next month = last day of this month
    property int    _daysInMonth:  new Date(_todayYear, _todayMonth + 1, 0).getDate()

    // Total cells = leading blank offsets + actual day cells
    property int    _cellCount:    _startOffset + _daysInMonth

    // Month name for the header label
    property string _monthLabel:  Qt.formatDateTime(_today, "MMMM yyyy").toUpperCase()

    // -------------------------------------------------------------------------
    // HEADER — Month + Year
    // -------------------------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 12

        Text {
            text:           calRoot._monthLabel
            color:          Config.ThemeConfig.colors.primary
            font.pixelSize: 11
            font.bold:      true
            font.family:    "monospace"
            font.letterSpacing: 1.5
        }

        Item { Layout.fillWidth: true }
    }

    // -------------------------------------------------------------------------
    // DAY-OF-WEEK HEADER ROW — S M T W T F S
    // -------------------------------------------------------------------------
    GridLayout {
        id: dayHeader
        Layout.fillWidth: true
        columns:          7
        columnSpacing:    4
        rowSpacing:       0

        Repeater {
            model: ["S", "M", "T", "W", "T", "F", "S"]
            delegate: Text {
                Layout.alignment:   Qt.AlignHCenter
                text:               modelData
                color:              Config.ThemeConfig.colors.textDim
                font.pixelSize:     9
                font.bold:          true
                font.family:        "monospace"
                font.letterSpacing: 1.0
            }
        }
    }

    // Small gap between header and cells
    Rectangle {
        Layout.fillWidth:  true
        height:            1
        color:             Config.ThemeConfig.colors.outlineVariant
        Layout.topMargin:  6
        Layout.bottomMargin: 6
    }

    // -------------------------------------------------------------------------
    // CALENDAR CELL GRID
    // model = _cellCount covers both blank offset cells and real day cells.
    // Cell displays nothing if index < _startOffset (leading blank).
    // -------------------------------------------------------------------------
    GridLayout {
        id: calGrid
        Layout.fillWidth:  true
        columns:           7
        columnSpacing:     4
        rowSpacing:        4

        Repeater {
            model: calRoot._cellCount

            delegate: Item {
                Layout.preferredWidth:  24
                Layout.preferredHeight: 24
                Layout.alignment:       Qt.AlignHCenter | Qt.AlignVCenter

                // Resolve this cell's day number (0 = blank offset cell)
                readonly property int dayNumber: (index < calRoot._startOffset)
                                                 ? 0
                                                 : (index - calRoot._startOffset + 1)

                readonly property bool isToday: (dayNumber === calRoot._todayDay)
                readonly property bool isBlank: (dayNumber === 0)

                // Highlight chip for today — inverted (white bg, dark text)
                Rectangle {
                    anchors.fill: parent
                    radius:       0
                    color:        parent.isToday ? Config.ThemeConfig.colors.primary : "transparent"
                    visible:      !parent.isBlank
                }

                Text {
                    anchors.centerIn: parent
                    visible:         !parent.isBlank
                    text:            parent.dayNumber.toString()
                    color:           parent.isToday ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.textDim
                    font.pixelSize:  10
                    font.bold:       parent.isToday
                    font.family:     "monospace"
                }
            }
        }
    }

    // Absorb remaining vertical space
    Item { Layout.fillHeight: true }
}
