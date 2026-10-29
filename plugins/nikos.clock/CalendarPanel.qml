// =============================================================================
// nikos.clock — calendar popup body ("TODAY CARD", upstream-Ryoku adaptation)
// =============================================================================
// Adaptation of Ryoku's TodayCard (their orpheus shell, user-provided photos)
// to this bar's design language (teal on pure black, JetBrains Mono):
//   ┌─ calendar ─────┐  ┌─ clock hero ──────────────┐
//   │ ‹ OCTOBER 2026 ›│  │ 10:38 PM :12    Sunday    │
//   │ MO TU .. SU     │  └───────────────────────────┘
//   │ grid, today =   │  ┌─ weather ─────┐ ┌ metrics ┐
//   │ filled circle   │  │ ☾ 49° Clear   │ │WIND HUM │
//   └─────────────────┘  │ Pennsylvania  │ │RAIN FEEL│
//                        └───────────────┘ └─────────┘
//                        ┌─ hourly curve (next 8h) ───┐
//                        │   49°–41° line + fill      │
//                        └────────────────────────────┘
// Card chrome is transparent + 1px hairline (QD-OLED: no bright static fills;
// the ephemeral popup is the one place a filled accent circle is allowed).
// Weather data: the plugin's WeatherService singleton (open-gated fetch);
// pure parsing/curve slicing lives in lib/weather.mjs (node-tested).
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "lib/tz.mjs" as Tz
import "lib/weather.mjs" as Wx
import "lib/calendar.mjs" as Cal
import "." as Clock

RowLayout {
    id: calRoot

    property var ctx: null
    // Drives the hero clock's seconds: BarWidget sets this while the popup
    // is open, so the Seconds-precision SystemClock never ticks at rest
    // (idle-zero doctrine — the panel body stays loaded while closed).
    property bool live: false

    // ── clock face (J4) ──────────────────────────────────────────────────────
    // `clockFace = "dot"` switches the LARGE clocks to Doto (variable
    // dot-matrix font, ROND 100). The ≥ 26 px rule: the dot grid is illegible
    // smaller, so the bar pill (12 px) and the ":ss" ticker (13 px) stay in
    // the bar font — only this 34 px hero (and the lock's 104 px clock,
    // which mirrors this via LockConfig's direct settings read) qualify.
    // NOTE the reads go through ctx.settings.VALUES (the bindable access —
    // SettingsStore header): get() inside a binding is opaque, it would
    // freeze at whatever the values were at mount.
    readonly property bool _heroDot: ctx !== null
        && ctx.settings.values.clockFace === "dot"
    readonly property bool _heroBlink: ctx !== null
        && ctx.settings.values.colonBlink === true
    property bool _colonOn: true
    Timer {
        // Colon blink — opacity-only (no text swap) so the layout never
        // reflows regardless of Doto's metrics. Runs ONLY while the panel
        // is open (`live`); resets to visible on stop so closing the panel
        // mid-dark-phase can't park the colon dark.
        interval: 530; repeat: true
        running: calRoot.live && calRoot._heroBlink
        onRunningChanged: if (!running) calRoot._colonOn = true
        onTriggered: calRoot._colonOn = !calRoot._colonOn
    }

    Layout.fillWidth: true
    spacing: 12

    // ── "now" — minutes; Seconds only while the panel is open ───────────────
    SystemClock {
        id: clk
        precision: calRoot.live ? SystemClock.Seconds : SystemClock.Minutes
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
    // Grid math lives in shared/calendar.mjs (DU6 — the settings Dashboard
    // hero calendar runs the same module; this used to be an identical fork).
    readonly property int _startOffset: Cal.startOffset(viewYear, viewMonth)
    readonly property int _daysInMonth: Cal.daysInMonth(viewYear, viewMonth)
    readonly property int _cellCount: Cal.CELL_COUNT

    function _shiftMonth(delta) {
        var r = Cal.shiftMonth(calRoot.viewYear, calRoot.viewMonth, delta)
        calRoot.viewYear  = r.year
        calRoot.viewMonth = r.month
    }

    // ── weather ──────────────────────────────────────────────────────────────
    readonly property bool _weatherData: Clock.WeatherService.weather && Clock.WeatherService.weather.available
    readonly property bool _wxLive: ctx
        && Clock.WeatherService.showWeather
        && (calRoot._weatherData
            || Clock.WeatherService.state === "loading"
            || Clock.WeatherService.state === "error")

    // The hour cards' slice — re-evaluated as the clock ticks so "now"
    // advances while the panel sits open.
    readonly property var _hours: calRoot._weatherData
        ? Wx.sliceAhead(Clock.WeatherService.weather.hourly, Clock.WeatherService.nowStamp(clk.date), 8)
        : []

    // 12h label for an hour row ("22" → "10 PM") — the hero clock's idiom.
    function _hourLabel(row) {
        var hh = Number(String(row.t).slice(11, 13))
        var ap = hh >= 12 ? "PM" : "AM"
        var h12 = hh % 12; if (h12 === 0) h12 = 12
        return h12 + " " + ap
    }

    // Zone-shifted hero clock (same zone setting as the bar pill). Through
    // .values — bindable — so a zone change live-applies without a remount.
    readonly property var _shifted: Tz.wallClock(calRoot._now,
        ctx && ctx.settings.values.zone !== undefined ? ctx.settings.values.zone : "Local")
    // 12-hour hero (upstream's style). Qt's "h" only goes 12h when AP is in
    // the SAME format string — "h:mm" plus a separate "AP" text yields
    // "19:01 PM", so the hour is converted by hand.
    readonly property int _heroHour12: (calRoot._shifted.getHours() % 12) === 0
                                       ? 12 : calRoot._shifted.getHours() % 12

    component Card: Rectangle {
        radius: 12
        color: "transparent"
        border.width: 1
        border.color: calRoot.ctx ? calRoot.ctx.theme.withAlpha(calRoot.ctx.theme.colors.text, 0.14) : "#222"
    }

    // J6 — preset/stop pill of the FOCUS card (transparent + hairline like
    // every control here; accent on hover).
    component FocusPill: Rectangle {
        id: pillRoot
        property string label: ""
        signal activated()

        width: pillLabel.implicitWidth + 20
        height: 22
        radius: 6
        color: pillMa.containsMouse
               ? (calRoot.ctx ? calRoot.ctx.theme.withAlpha(calRoot.ctx.theme.colors.text, 0.08) : "#111")
               : "transparent"
        border.width: 1
        border.color: pillMa.containsMouse
                      ? (calRoot.ctx ? calRoot.ctx.theme.colors.accent : "#0ff")
                      : (calRoot.ctx ? calRoot.ctx.theme.withAlpha(calRoot.ctx.theme.colors.text, 0.25) : "#333")
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Text {
            id: pillLabel
            anchors.centerIn: parent
            text: pillRoot.label
            color: pillMa.containsMouse
                   ? (calRoot.ctx ? calRoot.ctx.theme.colors.accent : "#0ff")
                   : (calRoot.ctx ? calRoot.ctx.theme.colors.text : "#ddd")
            font.family: calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace"
            font.pixelSize: 10; font.bold: true
        }
        MouseArea {
            id: pillMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pillRoot.activated()
        }
    }

    // ═══ LEFT — month calendar card ══════════════════════════════════════════
    Card {
        id: calCard

        Layout.preferredWidth: 236
        Layout.preferredHeight: 300
        Layout.fillHeight: true   // stretch to the right column's height — bottoms align

        readonly property real pad: 14
        readonly property real cellW: (width - 2 * pad - 6 * 3) / 7
        readonly property real cellH: 27

        Column {
            anchors.fill: parent
            anchors.margins: parent.pad

            // ‹ OCTOBER 2026 ›
            Item {
                width: parent.width
                height: 26

                Text {
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(calRoot._firstOfMonth, "MMMM").toUpperCase()
                          + "  " + calRoot.viewYear
                    color: calRoot.ctx ? calRoot.ctx.theme.colors.text : "#ddd"
                    font.family: calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace"
                    font.pixelSize: 12; font.bold: true; font.letterSpacing: 2
                }
                Repeater {
                    model: [-1, 1]
                    delegate: Text {
                        x: index === 0 ? 0 : parent.width - width
                        anchors.verticalCenter: parent.verticalCenter
                        text: index === 0 ? "‹" : "›"
                        color: navMa.containsMouse
                               ? (calRoot.ctx ? calRoot.ctx.theme.colors.accent : "#0ff")
                               : (calRoot.ctx ? calRoot.ctx.theme.colors.textDim : "#666")
                        font.family: calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace"
                        font.pixelSize: 15; font.bold: true

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

            // MO .. SU
            Grid {
                columns: 7
                columnSpacing: 3
                rowSpacing: 0
                width: parent.width

                Repeater {
                    model: ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
                    delegate: Item {
                        width: calCard.cellW
                        height: 20
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: calRoot.ctx ? calRoot.ctx.theme.colors.textDim : "#666"
                            font.family: calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace"
                            font.pixelSize: 8; font.bold: true; font.letterSpacing: 0.5
                        }
                    }
                }
            }

            // Day grid — adjacent-month cells are BLANK (upstream's minimalism)
            Grid {
                columns: 7
                columnSpacing: 3
                rowSpacing: 3
                width: parent.width

                Repeater {
                    model: calRoot._cellCount

                    delegate: Item {
                        width: calCard.cellW
                        height: calCard.cellH

                        readonly property int  dayNum:      index - calRoot._startOffset + 1
                        readonly property bool isActualDay: dayNum > 0 && dayNum <= calRoot._daysInMonth
                        readonly property bool isToday:     isActualDay && dayNum === calRoot._todayDay && calRoot._isThisMonth

                        // Today — filled accent circle with a black numeral
                        // (ephemeral popup: the one place doctrine allows it).
                        Rectangle {
                            anchors.centerIn: parent
                            width: 24; height: 24; radius: 12
                            visible: parent.isToday
                            color: calRoot.ctx ? calRoot.ctx.theme.colors.accent : "#0ff"
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: parent.isActualDay
                            text: parent.dayNum
                            font.family: calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace"
                            font.pixelSize: 11
                            font.bold: parent.isToday
                            color: parent.isToday
                                ? "#000000"
                                : (dayMa.containsMouse
                                   ? (calRoot.ctx ? calRoot.ctx.theme.colors.accent : "#0ff")
                                   : (calRoot.ctx ? calRoot.ctx.theme.colors.text : "#ddd"))
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: dayMa
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                            enabled: parent.isActualDay
                        }
                    }
                }
            }
        }
    }

    // ═══ RIGHT — clock hero · weather + metrics · hourly curve ══════════════
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignTop
        spacing: 12

        // ── Clock hero ────────────────────────────────────────────────────────
        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: 92

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 8

                // HH : MM as three Texts (J4): the middle one is the blinkable
                // colon, and dot-face switching stays per-segment. Opacity
                // blink only — no text swap, no reflow. Doto axes per google/
                // fonts: ROND 100 = full round dots, wght 600 ≈ the DemiBold
                // the plain face uses.
                RowLayout {
                    spacing: 0
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: String(calRoot._heroHour12).padStart(2, "0")
                        color: calRoot.ctx ? calRoot.ctx.theme.colors.text : "#ddd"
                        font.family: calRoot._heroDot ? "Doto"
                            : (calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace")
                        font.variableAxes: calRoot._heroDot ? ({ "ROND": 100, "wght": 600 }) : ({})
                        font.pixelSize: 34; font.weight: Font.DemiBold
                    }
                    Text {
                        text: ":"
                        color: calRoot.ctx ? calRoot.ctx.theme.colors.text : "#ddd"
                        opacity: calRoot._heroBlink ? (calRoot._colonOn ? 1 : 0.12) : 1
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        font.family: calRoot._heroDot ? "Doto"
                            : (calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace")
                        font.variableAxes: calRoot._heroDot ? ({ "ROND": 100, "wght": 600 }) : ({})
                        font.pixelSize: 34; font.weight: Font.DemiBold
                    }
                    Text {
                        text: Qt.formatDateTime(calRoot._shifted, "mm")
                        color: calRoot.ctx ? calRoot.ctx.theme.colors.text : "#ddd"
                        font.family: calRoot._heroDot ? "Doto"
                            : (calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace")
                        font.variableAxes: calRoot._heroDot ? ({ "ROND": 100, "wght": 600 }) : ({})
                        font.pixelSize: 34; font.weight: Font.DemiBold
                    }
                }
                Column {
                    spacing: 0
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                        text: Qt.formatDateTime(calRoot._shifted, "AP")
                        color: calRoot.ctx ? calRoot.ctx.theme.colors.textDim : "#666"
                        font.family: calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace"
                        font.pixelSize: 11; font.bold: true
                    }
                    Text {
                        text: ":" + Qt.formatDateTime(calRoot._shifted, "ss")
                        color: calRoot.ctx ? calRoot.ctx.theme.withAlpha(calRoot.ctx.theme.colors.text, 0.4) : "#555"
                        font.family: calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace"
                        font.pixelSize: 13
                    }
                }

                Item { Layout.fillWidth: true }

                Column {
                    spacing: 1
                    Text {
                        anchors.right: parent.right
                        text: Qt.formatDateTime(calRoot._shifted, "dddd")
                        color: calRoot.ctx ? calRoot.ctx.theme.colors.text : "#ddd"
                        font.family: calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace"
                        font.pixelSize: 14; font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.right: parent.right
                        text: Qt.formatDateTime(calRoot._shifted, "MMMM d")
                        color: calRoot.ctx ? calRoot.ctx.theme.colors.textDim : "#666"
                        font.family: calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace"
                        font.pixelSize: 10
                    }
                }
            }
        }

        // ── Focus (J6) — starts the velocity.focus timer via the bar IPC ─────
        // ctx.run (sh is declared in this plugin's manifest.commands) shells
        // to `qs -c bar ipc call focus …`; the plugin's own bar pill carries
        // the live countdown, so this card probes status once per OPEN and
        // updates optimistically on click — no polling while it sits open.
        Card {
            id: focusCard
            Layout.fillWidth: true
            Layout.preferredHeight: 44

            property bool focusRunning: false
            property string focusRemaining: ""

            Process {
                id: focusStatus   // unbounded-ok: one-shot probe per panel open
                stdout: SplitParser {
                    onRead: function(line) {
                        try {
                            var d = JSON.parse("" + line)
                            focusCard.focusRunning = d.running === true
                            focusCard.focusRemaining = typeof d.remaining === "string" ? d.remaining : ""
                        } catch (e) {
                            focusCard.focusRunning = false   // plugin off / not loaded
                        }
                    }
                }
            }
            function probe() {
                focusStatus.command = ["sh", "-c", "qs -c bar ipc call focus status"]
                focusStatus.running = true
            }
            function launch(mins) {
                focusCard.focusRunning = true
                focusCard.focusRemaining = mins + ":00"
                if (calRoot.ctx) calRoot.ctx.run(["sh", "-c", "qs -c bar ipc call focus start " + mins])
            }
            function cancel() {
                focusCard.focusRunning = false
                focusCard.focusRemaining = ""
                if (calRoot.ctx) calRoot.ctx.run(["sh", "-c", "qs -c bar ipc call focus stop"])
            }
            Connections {
                target: calRoot
                function onLiveChanged() { if (calRoot.live) focusCard.probe() }
            }
            Component.onCompleted: if (calRoot.live) focusCard.probe()

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 10

                Text {
                    text: "󰥔"
                    color: focusCard.focusRunning
                           ? (calRoot.ctx ? calRoot.ctx.theme.colors.accent : "#0ff")
                           : (calRoot.ctx ? calRoot.ctx.theme.withAlpha(calRoot.ctx.theme.colors.text, 0.4) : "#555")
                    font.family: calRoot.ctx ? calRoot.ctx.bar.fontNerd : "monospace"
                    font.pixelSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    Layout.fillWidth: true
                    text: focusCard.focusRunning
                          ? "FOCUS  " + focusCard.focusRemaining
                          : "FOCUS — PICK A LENGTH"
                    color: focusCard.focusRunning
                           ? (calRoot.ctx ? calRoot.ctx.theme.colors.accent : "#0ff")
                           : (calRoot.ctx ? calRoot.ctx.theme.colors.textDim : "#666")
                    font.family: calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace"
                    font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.5
                    elide: Text.ElideRight
                }
                Row {
                    visible: !focusCard.focusRunning
                    spacing: 8
                    FocusPill { label: "15M"; onActivated: focusCard.launch(15) }
                    FocusPill { label: "25M"; onActivated: focusCard.launch(25) }
                    FocusPill { label: "50M"; onActivated: focusCard.launch(50) }
                }
                FocusPill {
                    visible: focusCard.focusRunning
                    label: "STOP"
                    onActivated: focusCard.cancel()
                }
            }
        }

        // ── Weather + metrics row (only while the weather block is live) ─────
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            visible: calRoot._wxLive

            // Loading / error states take the whole row
            Text {
                visible: !calRoot._weatherData && Clock.WeatherService.state === "loading"
                Layout.fillWidth: true
                text: "CONTACTING OPEN-METEO …"
                color: calRoot.ctx ? calRoot.ctx.theme.colors.textDim : "#666"
                font.family: calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace"
                font.pixelSize: 10; font.letterSpacing: 1.5
            }
            Text {
                visible: !calRoot._weatherData && Clock.WeatherService.state === "error"
                Layout.fillWidth: true
                text: "WEATHER OFFLINE · RETRIES ON NEXT OPEN"
                color: calRoot.ctx ? calRoot.ctx.theme.colors.textDim : "#666"
                font.family: calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace"
                font.pixelSize: 10; font.letterSpacing: 1.5
            }

            // Current conditions
            Card {
                visible: calRoot._weatherData
                Layout.fillWidth: true
                Layout.preferredHeight: 104

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.topMargin: 12
                    anchors.bottomMargin: 12
                    spacing: 2

                    Row {
                        spacing: 10
                        Text {
                            text: Clock.WeatherService.glyph
                            color: calRoot.ctx ? calRoot.ctx.theme.colors.accent : "#0ff"
                            font.family: calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace"
                            font.pixelSize: 30
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: Clock.WeatherService.weather ? Clock.WeatherService.weather.tempNow + "°" : ""
                            color: calRoot.ctx ? calRoot.ctx.theme.colors.text : "#ddd"
                            font.family: calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace"
                            font.pixelSize: 30; font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    Text {
                        text: Clock.WeatherService.weather ? Clock.WeatherService.weather.condition : ""
                        color: calRoot.ctx ? calRoot.ctx.theme.colors.text : "#ddd"
                        font.family: calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace"
                        font.pixelSize: 11
                    }
                    Text {
                        text: Clock.WeatherService.placeLabel
                              + (Clock.WeatherService.state === "stale" ? "  ·  STALE" : "")
                        color: calRoot.ctx ? calRoot.ctx.theme.colors.textDim : "#666"
                        font.family: calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace"
                        font.pixelSize: 9
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            // Metrics 2×2 — WIND / HUMIDITY / RAIN / FEELS
            Card {
                id: metricsCard

                visible: calRoot._weatherData
                Layout.preferredWidth: 128
                Layout.preferredHeight: 104

                Grid {
                    anchors.fill: parent
                    anchors.margins: 12
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 8

                    Repeater {
                        model: [
                            { v: Clock.WeatherService.weather ? Clock.WeatherService.weather.wind : "", l: "WIND" },
                            { v: Clock.WeatherService.weather ? Clock.WeatherService.weather.humidity + "%" : "", l: "HUMIDITY" },
                            { v: calRoot._hours.length > 1 ? calRoot._hours[1].precip + "%"
                                : (calRoot._hours.length ? calRoot._hours[0].precip + "%" : ""), l: "RAIN" },
                            { v: Clock.WeatherService.weather ? Clock.WeatherService.weather.feels + "°" : "", l: "FEELS" }
                        ]
                        delegate: Column {
                            width: (metricsCard.width - 24 - 10) / 2
                            Text {
                                text: modelData.v
                                color: calRoot.ctx ? calRoot.ctx.theme.colors.text : "#ddd"
                                font.family: calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace"
                                font.pixelSize: 14; font.weight: Font.DemiBold
                            }
                            Text {
                                text: modelData.l
                                color: calRoot.ctx ? calRoot.ctx.theme.colors.textDim : "#666"
                                font.family: calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace"
                                font.pixelSize: 8; font.letterSpacing: 1
                            }
                        }
                    }
                }
            }
        }

        // ── Hourly curve — next 8 hours from the current one ─────────────────
        Card {
            id: curveCard
            visible: calRoot._weatherData
            Layout.fillWidth: true
            Layout.preferredHeight: 118

            property var slice: calRoot._hours

            onSliceChanged: curve.requestPaint()

            Canvas {
                id: curve
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 8
                anchors.bottomMargin: 34
                antialiasing: true

                onPaint: {
                    var ctx2 = getContext("2d")
                    ctx2.reset()
                    var rows = curveCard.slice
                    if (rows.length < 2) return
                    var w = width, h = height
                    var n = rows.length
                    var min = rows[0].temp, max = rows[0].temp
                    for (var i = 1; i < n; i++) {
                        if (rows[i].temp < min) min = rows[i].temp
                        if (rows[i].temp > max) max = rows[i].temp
                    }
                    var pad = 14
                    var span = (max - min) || 1
                    var pts = []
                    for (var j = 0; j < n; j++) {
                        pts.push({
                            x: (j + 0.5) * w / n,
                            y: pad + (1 - (rows[j].temp - min) / span) * (h - 2 * pad)
                        })
                    }
                    // gradient fill under the line — derived from the accent
                    // TOKEN (themes vary; a hardcoded teal goes wrong under
                    // every non-teal accent)
                    var acc = calRoot.ctx ? calRoot.ctx.theme.colors.accent : Qt.color("#00dce5")
                    var grad = ctx2.createLinearGradient(0, 0, 0, h)
                    grad.addColorStop(0, Qt.rgba(acc.r, acc.g, acc.b, 0.16))
                    grad.addColorStop(1, Qt.rgba(acc.r, acc.g, acc.b, 0.0))
                    ctx2.beginPath()
                    ctx2.moveTo(pts[0].x, pts[0].y)
                    for (var k = 1; k < n; k++) ctx2.lineTo(pts[k].x, pts[k].y)
                    ctx2.lineTo(pts[n - 1].x, h)
                    ctx2.lineTo(pts[0].x, h)
                    ctx2.closePath()
                    ctx2.fillStyle = grad
                    ctx2.fill()
                    // the line
                    ctx2.beginPath()
                    ctx2.moveTo(pts[0].x, pts[0].y)
                    for (var m = 1; m < n; m++) ctx2.lineTo(pts[m].x, pts[m].y)
                    ctx2.strokeStyle = acc
                    ctx2.lineWidth = 1.5
                    ctx2.stroke()
                    // point dot + temp labels above
                    ctx2.fillStyle = acc
                    ctx2.beginPath()
                    ctx2.arc(pts[0].x, pts[0].y, 2.5, 0, Math.PI * 2)
                    ctx2.fill()
                    ctx2.fillStyle = calRoot.ctx ? calRoot.ctx.theme.colors.textDim : "#666"
                    ctx2.font = "600 8px " + (calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace")
                    ctx2.textAlign = "center"
                    for (var t = 0; t < n; t++) {
                        ctx2.fillText(rows[t].temp + "°", pts[t].x, Math.max(8, pts[t].y - 6))
                    }
                }

                Connections {
                    target: calRoot
                    function onWxDataChanged() { curve.requestPaint() }
                }
                onWidthChanged: requestPaint()
            }

            // hour row — glyph + label under each curve point
            Row {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                height: 30

                Repeater {
                    model: curveCard.slice

                    delegate: Item {
                        width: curveCard.slice.length
                               ? curve.width / curveCard.slice.length : 0
                        height: 30

                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Wx.nerdFor(modelData.code, modelData.isDay)
                                color: calRoot.ctx ? calRoot.ctx.theme.withAlpha(calRoot.ctx.theme.colors.accent, 0.7) : "#0aa"
                                font.family: calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace"
                                font.pixelSize: 11
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: calRoot._hourLabel(modelData)
                                color: calRoot.ctx ? calRoot.ctx.theme.colors.textDim : "#666"
                                font.family: calRoot.ctx ? calRoot.ctx.bar.fontFamily : "monospace"
                                font.pixelSize: 8
                            }
                        }
                    }
                }
            }
        }
    }
}
