// =============================================================================
// nikos.clock — calendar popup body ("TEMPORAL MAP", Omarchy mockup port)
// =============================================================================
// Port of the dashboard CalendarWidget's month logic (MON-start offset, fixed
// 6-row grid, today-only highlight) restyled to the bar-popup mockup:
//   • eyebrow "TEMPORAL MAP :: Q3 // <TZ>"
//   • headline "SEPTEMBER 2026" (year in dim weight)
//   • meta "WEEK 37 • DAY 255 OF 365" (ISO week + day-of-year)
//   • adjacent-month ghost days, weekend dimming, per-cell hover
//   • today = primary reticle box (1.5px border + primary tint fill)
// All colours are live api tokens — re-tints on theme change.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: calRoot

    property var api: null

    Layout.fillWidth: true
    spacing: 0

    // ── "now" — hour precision (the day only changes at midnight) ───────────
    SystemClock {
        id: clk
        precision: SystemClock.Hours
    }
    property var _now: clk.date

    readonly property int _todayDay:   calRoot._now.getDate()
    readonly property int _todayMonth: calRoot._now.getMonth()
    readonly property int _todayYear:  calRoot._now.getFullYear()

    // View state — prev/next shift it; today highlights only when the viewed
    // month IS the current month.
    property int viewMonth: calRoot._todayMonth
    property int viewYear:  calRoot._todayYear

    readonly property bool _isThisMonth: viewMonth === _todayMonth && viewYear === _todayYear

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

    // ISO-8601 week number (mockup: "WEEK 37")
    function _isoWeek(d) {
        var t = new Date(d.getFullYear(), d.getMonth(), d.getDate())
        t.setDate(t.getDate() + 3 - ((t.getDay() + 6) % 7))
        var week1 = new Date(t.getFullYear(), 0, 4)
        return 1 + Math.round(((t - week1) / 86400000 - 3 + ((week1.getDay() + 6) % 7)) / 7)
    }

    // Day-of-year (mockup: "DAY 255 OF 365"). Math.round, not floor — DST
    // makes some local days 23h, which floor turns into an off-by-one.
    function _dayOfYear(d) {
        var start = new Date(d.getFullYear(), 0, 0)
        return Math.round((d - start) / 86400000)
    }

    function _daysInYear(y) {
        return (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0 ? 366 : 365
    }

    // TZ label for the eyebrow — the clock anchor's configured offset/city.
    readonly property string _tzLabel: {
        if (!api) return "LOCAL"
        var city = (api.bar.clockCity || "").trim()
        if (city.length > 0 && city.toLowerCase() !== "local")
            return city.toUpperCase()
        var off = api.bar.clockOffset || 0
        if (off === 0) return "LOCAL"
        return "UTC" + (off > 0 ? "+" : "") + off
    }

    // Cell metrics — 7 columns across the panel body.
    readonly property real cellW: (calRoot.width - 6 * 4) / 7   // 4px column spacing
    readonly property real cellH: 30

    // ── HEADER — eyebrow · headline · meta · nav ─────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 10
        spacing: 8

        ColumnLayout {
            spacing: 2

            // Eyebrow — TEMPORAL MAP :: Q3 // TZ
            Row {
                spacing: 6
                Text {
                    text: "TEMPORAL MAP"
                    color: api ? api.theme.colors.primary : "#7aa2f7"
                    font.family: api ? api.bar.fontFamily : "monospace"
                    font.pixelSize: 9; font.bold: true; font.letterSpacing: 2.2
                }
                Text {
                    text: "::"
                    color: api ? api.theme.withAlpha(api.theme.colors.text, 0.18) : "#243242"
                    font.family: api ? api.bar.fontFamily : "monospace"
                    font.pixelSize: 9; font.bold: true
                }
                Text {
                    text: "Q" + (Math.floor(calRoot.viewMonth / 3) + 1) + " // " + calRoot._tzLabel
                    color: api ? api.theme.colors.textDim : "#666"
                    font.family: api ? api.bar.fontFamily : "monospace"
                    font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.2
                }
            }

            // Headline — SEPTEMBER <dim>2026</dim>
            Row {
                spacing: 7
                Text {
                    text: Qt.formatDateTime(calRoot._firstOfMonth, "MMMM").toUpperCase()
                    color: api ? api.theme.colors.text : "#ddd"
                    font.family: api ? api.bar.fontFamily : "monospace"
                    font.pixelSize: 22; font.weight: Font.DemiBold
                    font.letterSpacing: 3
                }
                Text {
                    text: String(calRoot.viewYear)
                    color: api ? api.theme.colors.textDim : "#888"
                    font.family: api ? api.bar.fontFamily : "monospace"
                    font.pixelSize: 21; font.weight: Font.Light
                }
            }

            // Meta — WEEK 37 • DAY 255 OF 365
            Text {
                text: {
                    var d = new Date(calRoot._todayYear, calRoot._todayMonth, calRoot._todayDay)
                    return "WEEK " + calRoot._isoWeek(d) +
                           " • DAY " + calRoot._dayOfYear(d) +
                           " OF " + calRoot._daysInYear(d.getFullYear())
                }
                color: api ? api.theme.colors.textDim : "#666"
                font.family: api ? api.bar.fontFamily : "monospace"
                font.pixelSize: 9; font.letterSpacing: 0.8
            }
        }

        Item { Layout.fillWidth: true }

        // Prev / Next month chevrons — precision terminal buttons
        Row {
            spacing: 6

            Repeater {
                model: [ -1, 1 ]

                delegate: Rectangle {
                    width: 28; height: 28; radius: 6
                    color: navMa.containsMouse
                           ? (api ? api.theme.withAlpha(api.theme.colors.primary, 0.10) : "#111")
                           : (api ? api.theme.withAlpha(api.theme.colors.surface, 0.6) : "#07090d")
                    border.color: navMa.containsMouse
                                  ? (api ? api.theme.colors.primary : "#7aa2f7")
                                  : (api ? api.theme.colors.outlineVariant : "#222")
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData < 0 ? "‹" : "›"
                        color: navMa.containsMouse
                               ? (api ? api.theme.colors.primary : "#7aa2f7")
                               : (api ? api.theme.colors.textDim : "#999")
                        font.family: api ? api.bar.fontFamily : "monospace"
                        font.pixelSize: 15; font.bold: true
                        Behavior on color { ColorAnimation { duration: 120 } }
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
    }

    // ── WEEK HEADER — accent M-F, dim S S, hairline below ────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Grid {
            id: weekRow
            columns: 7
            columnSpacing: 4
            Layout.fillWidth: true

            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]

                delegate: Item {
                    width: calRoot.cellW
                    height: 18

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        // Weekends dim (mockup: S S in textDim), weekdays accent.
                        color: index < 5
                               ? (api ? api.theme.withAlpha(api.theme.colors.primary, 0.8) : "#7aa2f7")
                               : (api ? api.theme.colors.textDim : "#666")
                        font.family: api ? api.bar.fontFamily : "monospace"
                        font.pixelSize: 10; font.bold: true; font.letterSpacing: 1
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: api ? api.theme.withAlpha(api.theme.colors.text, 0.08) : "#141b24"
        }
    }

    // ── DAY GRID — fixed 6 rows, ghost adjacent months, today reticle ────────
    GridLayout {
        columns: 7
        rows: 6
        columnSpacing: 4
        rowSpacing: 4
        Layout.fillWidth: true
        Layout.topMargin: 6

        Repeater {
            model: calRoot._cellCount

            delegate: Item {
                // GridLayout sizes children by IMPLICIT dimensions — setting
                // width/height is ignored and every cell collapses to 0.
                implicitWidth: calRoot.cellW
                implicitHeight: calRoot.cellH

                readonly property int  dayNum:      index - calRoot._startOffset + 1
                readonly property bool isActualDay: dayNum > 0 && dayNum <= calRoot._daysInMonth
                readonly property bool isToday:     isActualDay && dayNum === calRoot._todayDay && calRoot._isThisMonth
                // MON-start grid → columns 5 (SAT) & 6 (SUN) are the weekend.
                readonly property bool isWeekend:   (index % 7 === 5) || (index % 7 === 6)

                // Today — primary reticle box: soft outer glow (mockup's
                // box-shadow), tint fill, 1.5px border, bold primary text.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: 6
                    visible: parent.isToday
                    color: "transparent"
                    border.width: 4
                    border.color: api ? api.theme.withAlpha(api.theme.colors.primary, 0.10) : "transparent"
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    visible: parent.isToday
                    color: api ? api.theme.withAlpha(api.theme.colors.primary, 0.10) : "#0a1220"
                    border.width: 1.5
                    border.color: api ? api.theme.colors.primary : "#7aa2f7"
                    Behavior on border.color { ColorAnimation { duration: 160 } }
                }

                // Hover wash — every real day (mockup hover idiom)
                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    visible: parent.isActualDay && !parent.isToday && cellMa.containsMouse
                    color: api ? api.theme.withAlpha(api.theme.colors.primary, 0.07) : "#0d121a"
                }

                Text {
                    anchors.centerIn: parent
                    // Adjacent-month ghost days stay visible (mockup fidelity).
                    // JS Date normalizes out-of-range day numbers, so the raw
                    // (possibly negative or overflowing) dayNum rolls into the
                    // neighbouring month on its own.
                    text: parent.isActualDay ? parent.dayNum
                        : new Date(calRoot.viewYear, calRoot.viewMonth, parent.dayNum).getDate()
                    font.family: api ? api.bar.fontFamily : "monospace"
                    font.pixelSize: 13
                    font.bold: parent.isToday
                    color: {
                        var th = api ? api.theme : null
                        if (!th) return "#888"
                        if (parent.isToday) return th.colors.primary
                        if (!parent.isActualDay) return th.withAlpha(th.colors.text, 0.16)   // ghost
                        if (cellMa.containsMouse) return th.colors.primary
                        return parent.isWeekend ? th.colors.textDim : th.colors.text
                    }
                    opacity: (parent.isWeekend && parent.isActualDay && !parent.isToday) ? 0.75 : 1.0
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                MouseArea {
                    id: cellMa
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    enabled: parent.isActualDay
                }
            }
        }
    }
}
