// =============================================================================
// nikos.clock — CENTER-slot plugin (plugin ctx 2)
// =============================================================================
// Center anchor pill: date-time · live weather glyph · temperature.
//   • time click    → this plugin's CALENDAR popup (TEMPORAL MAP styling)
//   • weather click → force a refresh of the embedded WeatherSource fetcher
// Colours ride ctx tokens. Hover-only accents; popups do not recolor the anchor.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Ui

Item {
    id: root

    property var ctx: null

    // Host IPC (plugins summon/hide) routes through these — same contract as
    // the weather plugin's root.
    function toggle() { calPanel.toggle() }
    function open()   { calPanel.open() }
    function close()  { calPanel.close() }

    width: anchorRow.implicitWidth + 24
    height: ctx ? ctx.bar.barHeight : 30

    // Minute-boundary exact (a 60s Timer drifts when created mid-minute).
    SystemClock {
        id: clk
        precision: SystemClock.Minutes
    }

    // Embedded weather fetcher — self-contained (no cross-plugin import).
    WeatherSource {
        id: wxSource
    }

    readonly property var _days:   ["SUN","MON","TUE","WED","THU","FRI","SAT"]
    readonly property var _fullDays: ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
    readonly property var _months: ["JAN","FEB","MAR","APR","MAY","JUN",
                                    "JUL","AUG","SEP","OCT","NOV","DEC"]

    function _shifted(d) {
        var off = ctx ? ctx.bar.clockOffset : 0
        if (off !== 0) {
            var utc = d.getTime() + (d.getTimezoneOffset() * 60000)
            d = new Date(utc + (off * 3600000))
        }
        return d
    }

    function _formattedTime(d) {
        var s = root._shifted(d)
        return String(s.getHours()).padStart(2, "0") + ":" + String(s.getMinutes()).padStart(2, "0")
    }

    function _formattedDate(d) {
        var s = root._shifted(d)
        var out = root._fullDays[s.getDay()] + " " + root._formattedTime(d)
        var city = ctx ? (ctx.bar.clockCity || "").trim() : ""
        if (city.length > 0 && city.toLowerCase() !== "local")
            out += " · " + city.toUpperCase()
        return out
    }

    // Anchor cluster — borderless: "Saturday 15:41" · live weather glyph ·°C
    // PASSIVE handlers only (HoverHandler/TapHandler): a sibling MouseArea's
    // hover-steal made containsMouse never fire on hover, then stick true
    // after a click (accent frozen). Passive handlers coexist cleanly.
    Rectangle {
        anchors.centerIn: parent
        implicitWidth: anchorRow.implicitWidth + 24
        height: ctx ? ctx.bar.barHeight - 6 : 20
        radius: 6
        color: anchorHover.hovered ? ctx.theme.withAlpha(ctx.theme.colors.text, 0.06)
                                   : "transparent"
        HoverHandler { id: anchorHover }

        Row {
            id: anchorRow
            anchors.centerIn: parent
            spacing: 10

            // Time text — click toggles the calendar popup
            Text {
                text: root._formattedDate(clk.date)
                font.family: ctx ? ctx.bar.fontFamily : "monospace"
                font.pixelSize: 12
                color: timeHover.hovered ? ctx.theme.colors.accent
                                         : (ctx ? ctx.theme.colors.text : "#ddd")
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 120 } }

                HoverHandler { id: timeHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: calPanel.toggle() }
            }

            // Live weather — condition glyph + temperature from the EMBEDDED
            // WeatherSource (self-contained; the nikos.weather plugin was
            // removed). Left click toggles the popup, right click refreshes.
            // Glyph matches the temperature's color.
            Item {
                width: wxRow.implicitWidth
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    id: wxRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: wxSource.glyph
                        font.family: ctx ? ctx.bar.fontNerd : "monospace"
                        font.pixelSize: 13
                        color: wxHover.hovered ? ctx.theme.colors.accent
                                               : (ctx ? ctx.theme.colors.success : "#888")
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Text {
                        visible: wxSource.hasData
                        text: wxSource.temp
                        font.family: ctx ? ctx.bar.fontFamily : "monospace"
                        font.pixelSize: 11
                        color: wxHover.hovered ? ctx.theme.colors.accent
                                               : (ctx ? ctx.theme.colors.text : "#ddd")
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                HoverHandler { id: wxHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: wxPanel.toggle() }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: wxSource.refresh()
                }
            }
        }
    }

    // ── CALENDAR POPUP — centered under the anchor, TEMPORAL MAP styling ────
    PluginPopup {
        id: calPanel
        ctx: root.ctx
        anchorItem: root
        title: "CALENDAR"
        icon: "󰃭"
        contentWidth: 336
        anchorX: "center"
        showHeader: false

        Loader {
            // Defer until ctx lands — the body binds its tokens at creation.
            // NOTE: the LOADER is the layout child — a Layout.fillWidth set
            // inside the loaded file does nothing; stretch it here or the
            // body computes its grid from a stale intrinsic width.
            Layout.fillWidth: true
            active: root.ctx !== null
            source: Qt.resolvedUrl("CalendarPanel.qml")
            onLoaded: item.ctx = root.ctx
        }
    }

    // ── WEATHER POPUP — ATMOSPHERE styling, fed by the embedded fetcher ─────
    // Its own slot (subKey "wx" → "nikos.clock.wx"), so a weather open
    // closes the calendar and vice versa.
    PluginPopup {
        id: wxPanel
        ctx: root.ctx
        anchorItem: root
        subKey: "wx"
        title: "ATMOSPHERE"
        icon: wxSource.glyph
        contentWidth: 380
        anchorX: "center"
        showHeader: false
        onOpen: wxSource.refresh()

        Loader {
            Layout.fillWidth: true
            active: root.ctx !== null
            source: Qt.resolvedUrl("WeatherPanel.qml")
            onLoaded: {
                item.hostBar = root.ctx ? root.ctx.bar : null
                item.hostTheme = root.ctx ? root.ctx.theme : null
                item.wx = wxSource
            }
        }
    }
}
