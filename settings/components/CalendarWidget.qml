// =============================================================================
// CalendarWidget.qml — "TEMPORAL MAP" calendar (Dashboard tab)
// =============================================================================
// Square hero calendar for the redesigned Dashboard's left column. Lives inside
// a DashboardCard (showBrackets) content slot — its body is `Item { anchors.fill
// }`, matching the slot's Item/anchors.fill contract.
//
// V8.00 redesign (mockup-faithful):
//   • Headline month + year with a "TEMPORAL MAP" eyebrow + prev/next month nav.
//   • MON-start week header (startOffset = (getDay()+6)%7).
//   • Today cell = primary outline + ~5% primary tint fill + bold primary text,
//     shown ONLY while viewing the current month (navigates away → no highlight).
//   • Weekend dimming retained. All colours are live ThemeConfig tokens.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

Item {
    id: calRoot

    // -------------------------------------------------------------------------
    // "Now" (refreshed once a minute so the today-highlight rolls over at midnight)
    // -------------------------------------------------------------------------
    property var _now: new Date()
    Timer {
        interval: 60000; running: true; repeat: true
        onTriggered: calRoot._now = new Date()
    }

    readonly property int _todayDay:   calRoot._now.getDate()
    readonly property int _todayMonth: calRoot._now.getMonth()
    readonly property int _todayYear:  calRoot._now.getFullYear()

    // -------------------------------------------------------------------------
    // View state — the month being looked at. Prev/next shift it; "today" badge
    // only highlights when the viewed month IS the current month.
    // -------------------------------------------------------------------------
    property int viewMonth: calRoot._todayMonth
    property int viewYear:  calRoot._todayYear

    readonly property bool _isThisMonth: (viewMonth === _todayMonth && viewYear === _todayYear)

    property var _firstOfMonth: new Date(viewYear, viewMonth, 1)
    readonly property int _startOffset: (calRoot._firstOfMonth.getDay() + 6) % 7   // MON-start
    readonly property int _daysInMonth: new Date(viewYear, viewMonth + 1, 0).getDate()
    readonly property int _cellCount: 42   // fixed 6-row grid

    function _shiftMonth(delta) {
        var m = calRoot.viewMonth + delta
        var y = calRoot.viewYear
        if (m < 0)       { m = 11; y -= 1 }
        else if (m > 11) { m = 0;  y += 1 }
        calRoot.viewMonth = m
        calRoot.viewYear  = y
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 0

        // --- Header: eyebrow + headline month/year + prev/next nav ------------
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 18
            spacing: 8

            ColumnLayout {
                spacing: 3
                Text {
                    text: "TEMPORAL MAP"
                    color: Config.ThemeConfig.colors.primary
                    font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 9; font.bold: true; font.letterSpacing: 2.0
                }
                Text {
                    text: Qt.formatDateTime(calRoot._firstOfMonth, "MMMM").toUpperCase()
                          + "  " + calRoot.viewYear
                    color: Config.ThemeConfig.colors.text
                    font.family: Config.SettingsConfig.fontFamily
                    font.pixelSize: 22; font.weight: Font.DemiBold
                }
            }

            Item { Layout.fillWidth: true }

            // Prev / Next month chevrons
            Repeater {
                model: [ -1, 1 ]
                delegate: Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.primary, navMa.containsMouse ? 0.06 : 0.0)
                    border.color: navMa.containsMouse
                                  ? Config.ThemeConfig.colors.primary
                                  : Config.ThemeConfig.colors.outlineVariant
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData < 0 ? "‹" : "›"
                        color: navMa.containsMouse
                               ? Config.ThemeConfig.colors.primary
                               : Config.ThemeConfig.colors.text
                        font.family: Config.ControlConfig.fontMono
                        font.pixelSize: 16; font.bold: true
                    }

                    MouseArea {
                        id: navMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calRoot._shiftMonth(modelData)
                    }
                }
            }
        }

        // --- Week header (MON-start) -----------------------------------------
        GridLayout {
            columns: 7
            columnSpacing: 2
            rowSpacing: 2
            Layout.fillWidth: true
            Layout.bottomMargin: 8

            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]
                delegate: Item {
                    Layout.fillWidth: true
                    implicitHeight: dayLabel.implicitHeight
                    Text {
                        id: dayLabel
                        anchors.centerIn: parent
                        text: modelData
                        color: Config.ThemeConfig.colors.textDim
                        font.pixelSize: 10; font.bold: true
                        font.family: Config.SettingsConfig.fontFamily
                        font.letterSpacing: 1
                    }
                }
            }
        }

        // --- Day grid ---------------------------------------------------------
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
                    readonly property bool isToday:     isActualDay && dayNum === calRoot._todayDay && calRoot._isThisMonth
                    // MON-start grid → columns 5 (SAT) & 6 (SUN) are the weekend.
                    readonly property bool isWeekend:   (index % 7 === 5) || (index % 7 === 6)

                    // Today highlight — primary outline + ~5% primary tint fill.
                    Rectangle {
                        anchors.fill: parent
                        color: parent.isToday
                               ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.primary, 0.06)
                               : "transparent"
                        border.width: 1
                        border.color: parent.isToday
                                      ? Config.ThemeConfig.colors.primary
                                      : "transparent"
                        visible: parent.isToday
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: parent.isActualDay ? parent.dayNum : ""
                        font.pixelSize: 12
                        font.family: Config.SettingsConfig.fontFamily
                        font.weight: parent.isToday ? Font.Bold : Font.Normal
                        color: {
                            if (parent.isToday) return Config.ThemeConfig.colors.primary
                            if (parent.isActualDay) {
                                return parent.isWeekend
                                       ? Config.ThemeConfig.colors.textDim
                                       : Config.ThemeConfig.colors.text
                            }
                            return "transparent"
                        }
                        opacity: (parent.isWeekend && parent.isActualDay && !parent.isToday) ? 0.5 : 1.0
                    }
                }
            }
        }
    }
}
