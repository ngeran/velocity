// =============================================================================
// CalendarWidget.qml — Ultra-Minimalist Bento Calendar
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "." as Components

Item {
    id: calRoot

    // -------------------------------------------------------------------------
    // Logic: Date Calculations
    // -------------------------------------------------------------------------
    property var    _now:          new Date()
    property int    _todayDay:     _now.getDate()
    property int    _todayMonth:   _now.getMonth()
    property int    _todayYear:    _now.getFullYear()
    
    property var    _firstOfMonth: new Date(_todayYear, _todayMonth, 1)
    property int    _startOffset:  _firstOfMonth.getDay() 
    property int    _daysInMonth:  new Date(_todayYear, _todayMonth + 1, 0).getDate()
    property int    _cellCount:    42 // Fixed 6-row grid for visual stability

    Timer {
        interval: 60000; running: true; repeat: true
        onTriggered: calRoot._now = new Date()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 0

        // --- SECTION: Widget Header ---
        Components.WidgetHeader {
            icon: "󰃭"
            label: "CALENDAR"
            Layout.bottomMargin: 15
        }

        // --- SECTION: Month/Year Display ---
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 24 
            spacing: 12

            Text {
                text: Qt.formatDateTime(calRoot._now, "MMMM").toUpperCase()
                color: Config.ThemeConfig.colors.primary
                font.pixelSize: 20
                font.weight: Font.ExtraBold
                font.family: Config.SettingsConfig.fontFamily
                font.letterSpacing: 0.5
            }

            Text {
                text: Qt.formatDateTime(calRoot._now, "yyyy")
                color: Config.ThemeConfig.colors.textDim
                font.pixelSize: 20
                font.weight: Font.Light
                font.family: Config.SettingsConfig.fontFamily
                opacity: 0.4
            }

            Item { Layout.fillWidth: true }
        }

        // --- SECTION: Day Labels (S M T W T F S) ---
        GridLayout {
            columns: 7
            columnSpacing: 2
            Layout.fillWidth: true
            Layout.bottomMargin: 10
            
            Repeater {
                model: ["S", "M", "T", "W", "T", "F", "S"]
                // Item wrapper (zero intrinsic width) matches the date-grid
                // delegate below, so GridLayout splits all 7 columns evenly
                // instead of sizing each column to its letter's glyph width
                // ("M"/"W" are wider than "T"/"S", which was throwing the
                // header out of alignment with the numbers underneath).
                delegate: Item {
                    Layout.fillWidth: true
                    implicitHeight: dayLabel.implicitHeight
                    Text {
                        id: dayLabel
                        anchors.centerIn: parent
                        text: modelData
                        color: Config.ThemeConfig.colors.secondary
                        opacity: 0.5
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.family: Config.SettingsConfig.fontFamily
                    }
                }
            }
        }

        // --- SECTION: The Calendar Grid ---
        GridLayout {
            id: dateGrid
            columns: 7
            rows: 6
            Layout.fillWidth: true
            Layout.fillHeight: true
            columnSpacing: 2
            rowSpacing: 2

            Repeater {
                model: calRoot._cellCount

                delegate: Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    readonly property int  dayNum:      index - calRoot._startOffset + 1
                    readonly property bool isActualDay: dayNum > 0 && dayNum <= calRoot._daysInMonth
                    readonly property bool isToday:     isActualDay && dayNum === calRoot._todayDay
                    readonly property bool isWeekend:   (index % 7 === 0) || (index % 7 === 6)

                    // 1. Today Highlight — sharp hairline frame (no radius, no bounce)
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.8
                        height: parent.height * 0.8
                        radius: 0
                        color: "transparent"
                        border.width: 1
                        border.color: Config.ThemeConfig.colors.secondary
                        visible: isToday
                        opacity: isToday ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                    }

                    // 2. Day Number
                    Text {
                        anchors.centerIn: parent
                        text: isActualDay ? dayNum : ""
                        font.pixelSize: 12
                        font.family: Config.SettingsConfig.fontFamily
                        font.weight: isToday ? Font.Bold : Font.Normal
                        
                        color: {
                            if (isToday) return Config.ThemeConfig.colors.secondary;
                            if (isActualDay) {
                                return isWeekend ? Config.ThemeConfig.colors.textDim : Config.ThemeConfig.colors.primary;
                            }
                            return "transparent";
                        }
                        
                        opacity: (isWeekend && !isToday) ? 0.35 : 1.0
                    }
                    
                    // The Indicator Dot has been removed to keep the numbers clear.
                }
            }
        }
    }
}
