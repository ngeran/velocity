// =============================================================================
// nikos.clock — CENTER-slot plugin (plugin ctx 2)
// =============================================================================
// Center anchor pill: date-time only.
//   • time click → this plugin's CALENDAR popup (TEMPORAL MAP styling)
// Colours ride ctx tokens. Hover-only accents; popups do not recolor the anchor.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Ui
import "lib/tz.mjs" as Tz
import "." as Clock

Item {
    id: root

    property var ctx: null

    // Weather refresh is open-gated (idle-zero at rest): every monitor's
    // panel funnels into the singleton, whose 15-min gate dedupes. `live`
    // downgrades the panel's hero clock to Minutes while closed, so its
    // Seconds-precision SystemClock never ticks at rest.
    Connections {
        target: calPanel
        function onOpenedChanged() {
            if (panelLoader.item) panelLoader.item.live = calPanel.opened
            if (calPanel.opened) Clock.WeatherService.panelOpened()
        }
    }

    // Host IPC (plugins summon/hide) routes through these.
    function toggle() { calPanel.toggle() }
    function open()   { calPanel.open() }
    function close()  { calPanel.close() }
    // refresh: the settings dashboard's WeatherCard nudges a fetch past the
    // 15-min gate (the card reads this plugin's cache as its data source).
    // Still idle-zero: nothing here fetches on a timer.
    function refresh() { Clock.WeatherService.refresh() }

    width: anchorRow.implicitWidth + 24
    height: ctx ? ctx.bar.barHeight : 30

    // Minute-boundary exact (a 60s Timer drifts when created mid-minute).
    SystemClock {
        id: clk
        precision: SystemClock.Minutes
    }

    // Overflow contract (engine fit plan): the width this root collapses to
    // when ctx.fit === "compact" — the "HH:MM" string.
    // A hidden probe measures the compact string in the real font without
    // waiting for the state to change, so the plan gets a true number.
    Text {
        id: compactProbe
        visible: false
        text: root._formattedTime(clk.date)
        font.family: ctx ? ctx.bar.fontFamily : "Space Mono"
        font.pixelSize: Math.max(9, Math.round(12 * (ctx ? ctx.bar.contentScale : 1)))
    }
    readonly property real compactWidth: 24 + anchorRow.spacing
                                         + compactProbe.implicitWidth

    readonly property var _days:   ["SUN","MON","TUE","WED","THU","FRI","SAT"]
    readonly property var _fullDays: ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
    readonly property var _months: ["JAN","FEB","MAR","APR","MAY","JUN",
                                    "JUL","AUG","SEP","OCT","NOV","DEC"]

    // Through .values (bindable), not get() — a zone change from the settings
    // app live-applies to the pill instead of freezing at the mount-time value.
    readonly property string zone: ctx && ctx.settings.values.zone !== undefined
                                   ? ctx.settings.values.zone : "Local"

    function _shifted(d) { return Tz.wallClock(d, root.zone) }

    function _formattedTime(d) {
        var s = root._shifted(d)
        return String(s.getHours()).padStart(2, "0") + ":" + String(s.getMinutes()).padStart(2, "0")
    }

    function _formattedDate(d) {
        var s = root._shifted(d)
        var out = root._fullDays[s.getDay()] + " " + root._formattedTime(d)
        if (!Tz.isLocalZone(root.zone))
            out += " · " + Tz.zoneCity(root.zone).toUpperCase()
        return out
    }

    // Anchor cluster — borderless: "Saturday 15:41"
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

            // Time text — click toggles the calendar popup. Compact (ctx.fit)
            // drops the weekday and keeps "HH:MM" only.
            Text {
                id: timeText
                text: (ctx && ctx.fit === "compact") ? root._formattedTime(clk.date)
                                                     : root._formattedDate(clk.date)
                font.family: ctx ? ctx.bar.fontFamily : "Space Mono"
                font.pixelSize: Math.max(9, Math.round(12 * (ctx ? ctx.bar.contentScale : 1)))
                color: timeHover.hovered ? ctx.theme.colors.accent
                                         : (ctx ? ctx.theme.colors.text : "#ddd")
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 120 } }

                HoverHandler { id: timeHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: calPanel.toggle() }
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
        contentWidth: 564
        anchorX: "center"
        showHeader: false

        Loader {
            id: panelLoader
            // Defer until ctx lands — the body binds its tokens at creation.
            // NOTE: the LOADER is the layout child — a Layout.fillWidth set
            // inside the loaded file does nothing; stretch it here or the
            // body computes its grid from a stale intrinsic width.
            Layout.fillWidth: true
            active: root.ctx !== null
            source: Qt.resolvedUrl("CalendarPanel.qml")
            onLoaded: {
                item.ctx = root.ctx
                item.live = calPanel.opened
            }
        }
    }
}
