// =============================================================================
// SystemMonitorOverlay.qml — realtime SYSTEM MONITOR dashboard
// =============================================================================
// Opened from the bar's btop icon (or SUPER+T). Mirrors the SYSTEM INFO popup
// (FastfetchOverlay) exactly in size + visual language — a 900×680 square flat
// card over a dim click-to-close backdrop, dim grid + corner brackets, a brand
// header with pulsing dot + nerd glyph + live-theme swatches + HOST + ESC, a
// REAL-TIME sub-header strip, a 3-column card grid, and a footer status bar.
//
// LAYOUT (matches SYSTEM INFO's 3-column grid)
//   HEADER      brand + 7 theme swatches + HOST + ESC
//   SUBHEADER   REAL-TIME // <os> // <kernel>
//   ROW 1       CPU_LOAD  (colSpan 3, full-width hero)
//   ROW 2       PROCESS_MATRIX (colSpan 2) | MEMORY + STORAGE (compact pair)
//   ROW 3       NETWORK_IO  (colSpan 3 strip)
//   FOOTER      TELEMETRY OK · POLL ACTIVE · [host] · clock
//
// THEME: every accent is a live Config.ThemeConfig.colors.* token, cycled across
// sections via swatchAt() (exactly like SYSTEM INFO) — CPU=secondary, memory=
// accent, storage=secondary, network=info. No hardcoded/clashing gradients: the
// only Canvas fills are single-hue alpha-fades of those same tokens.
//
// SAFETY: no per-frame animation. The three Canvas charts repaint only on poll
// (onDataChanged / onPctChanged) — once per 1.2s tick. Continuous animations are
// limited to small status-dot opacity pulses, each gated on `running: root.shown`.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../config" as Config
import "../services" as Services

PanelWindow {
    id: root

    property bool shown: false
    property string clockText: "--:--:--"

    visible: false
    function open() {
        visible = true
        shown = true
        Services.SystemMonitorService.active = true
        clockTimer.restart()
    }
    function close() {
        shown = false
        hideTimer.restart()
        Services.SystemMonitorService.active = false
    }
    function toggle() { shown ? close() : open() }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    aboveWindows: true
    focusable: true
    exclusionMode: ExclusionMode.Ignore

    onShownChanged: if (!shown) hideTimer.restart()
    Timer { id: hideTimer; interval: 220; onTriggered: if (!root.shown) root.visible = false }

    // ---- palette (every accent is a live ThemeConfig token) ----
    readonly property color cBg:        Config.ThemeConfig.colors.background
    readonly property color cText:      Config.ThemeConfig.colors.text
    readonly property color cDim:       Config.ThemeConfig.colors.textDim
    readonly property color cBorder:    Config.ThemeConfig.colors.border
    readonly property color cOutline:   Config.ThemeConfig.colors.outlineVariant
    readonly property color cSurface:   Config.ThemeConfig.colors.surfaceVariant
    readonly property color cPrimary:   Config.ThemeConfig.colors.primary
    readonly property color cSecondary: Config.ThemeConfig.colors.secondary   // CPU / storage
    readonly property color cSuccess:   Config.ThemeConfig.colors.success     // network / healthy
    readonly property color cWarn:      Config.ThemeConfig.colors.warning     // swap
    readonly property color cErr:       Config.ThemeConfig.colors.error       // spikes / hot
    readonly property color cInfo:      Config.ThemeConfig.colors.info        // network sparkline
    readonly property color cAccent:    Config.ThemeConfig.colors.accent      // memory / up rate

    // ---- fonts (match SYSTEM INFO: mono + nerd) ----
    readonly property string fontM: Config.ControlConfig.fontMono            // "JetBrains Mono"
    readonly property string fontN: "JetBrainsMono Nerd Font"                // nerd glyphs

    // ---- helpers ----
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function rgba(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","
             + Math.round(c.b * 255) + "," + a + ")"
    }
    function tempColor(c) {
        if (!c) return root.cDim
        if (c >= 80) return root.cErr
        if (c >= 60) return root.cWarn
        return root.cSuccess
    }
    function diskColor(pct) { if (pct >= 90) return cErr; if (pct >= 75) return cWarn; return cSecondary }
    function swatchAt(i) {
        var a = [cSecondary, cPrimary, cSuccess, cWarn, cErr, cInfo, cAccent]
        return a[i] || cBorder
    }
    function pad2(n) { return ("0" + n).slice(-2) }
    function fmtRate(b) {
        if (b === null || b === undefined) return "—"
        if (b < 0) return "0 B/s"
        if (b < 1024) return Math.round(b) + " B/s"
        if (b < 1048576) return (b / 1024).toFixed(1) + " KiB/s"
        return (b / 1048576).toFixed(2) + " MiB/s"
    }
    function fmtGB(g) { return (g || 0).toFixed(1) + "G" }
    function mountLabel(m) {
        if (!m) return "—"
        var s = m.toString()
        if (s === "/") return "root"
        var parts = s.split("/").filter(function (p) { return p.length > 0 })
        return parts.length ? parts[parts.length - 1] : "root"
    }
    // process severity dot: green <1%, yellow >5%, red >10% CPU
    function dotColor(pct) {
        var p = pct || 0
        if (p > 10) return root.cErr
        if (p > 5)  return root.cWarn
        return root.cSuccess
    }
    function avg(arr) {
        if (!arr || !arr.length) return 0
        var s = 0
        for (var i = 0; i < arr.length; i++) s += (arr[i] || 0)
        return s / arr.length
    }

    // ---- CPU aggregate + per-core data ----
    readonly property int cpuThreads: Services.SystemMonitorService.coreCount || 0
    readonly property var _perCore: Services.CoreEngineService.perCoreLoad || []
    readonly property var _perCoreClock: Services.SystemMonitorService.perCoreClock || []
    function clockAt(i) { return root._perCoreClock[i] || Services.CoreEngineService.cpuGhz || 0 }
    function tempAt(i)  { return (Services.SystemMonitorService.perCoreTemp || [])[i] || 0 }
    readonly property real cpuTotalPct: {
        var s = Services.CoreEngineService.cpuTotalPct
        return (s !== undefined && s !== null) ? s : root.avg(root._perCore)
    }
    // index of the hottest-loaded core, for the accent glow highlight
    readonly property int hottestCore: {
        var arr = root._perCore, hi = 0
        for (var i = 1; i < arr.length; i++) if ((arr[i] || 0) > (arr[hi] || 0)) hi = i
        return hi
    }
    // load % of the single busiest core (for the "BUSIEST" readout)
    readonly property int cpuMaxCore: {
        var arr = root._perCore, m = 0
        for (var i = 0; i < arr.length; i++) { var v = arr[i] || 0; if (v > m) m = v }
        return Math.round(m)
    }

    // ---- rolling history buffers (one Timer, one tick, three pushes —
    // poll-cadence only, never per-frame) ----
    readonly property int _histLen: 40
    // pre-fill with zeros so the bar histogram renders a full-width baseline
    // from the first frame (instead of bars growing one-by-one over ~48s)
    function _makeHist() { var a = []; for (var i = 0; i < root._histLen; i++) a.push(0); return a }
    property var _cpuBars: root._makeHist()
    property var _memBars: []
    property var _netBars: root._makeHist()
    readonly property real _netMax: {
        var m = 1024
        for (var i = 0; i < root._netBars.length; i++) if (root._netBars[i] > m) m = root._netBars[i]
        return m
    }
    Timer {
        interval: 1200
        running: root.shown
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var c = root._cpuBars.slice(); c.push(root.cpuTotalPct); while (c.length > root._histLen) c.shift(); root._cpuBars = c
            var m = root._memBars.slice(); m.push(Services.CoreEngineService.ramPct || 0); while (m.length > root._histLen) m.shift(); root._memBars = m
            var n = root._netBars.slice(); n.push(Services.SystemMonitorService.netDownRate || 0); while (n.length > root._histLen) n.shift(); root._netBars = n
        }
    }

    // ---- disks (ListModel → use .count / .get()) ----
    readonly property var _disks: Services.SystemMonitorService.disks
    readonly property int _diskCount: root._disks ? root._disks.count : 0
    readonly property var _primaryDisk: root._diskCount > 0 ? root._disks.get(0) : null

    // net up rate
    readonly property var _netUpRaw: Services.SystemMonitorService.netUpRate
    function netUpText() {
        return (root._netUpRaw === undefined || root._netUpRaw === null) ? "—" : root.fmtRate(root._netUpRaw)
    }

    // =========================================================================
    // DIM BACKDROP (click-outside = close)
    // =========================================================================
    Rectangle {
        anchors.fill: parent
        color: root.cBg
        opacity: root.shown ? 0.55 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 200 } }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // =========================================================================
    // CENTERED CARD (900×680 — same size as SYSTEM INFO / ZaiUsageOverlay)
    // =========================================================================
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 900
        height: 680
        color: root.cBg
        border.color: root.cBorder
        border.width: 1
        clip: true
        opacity: root.shown ? 1.0 : 0.0
        scale: root.shown ? 1.0 : 0.96
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Keys.onEscapePressed: root.close()
        MouseArea { anchors.fill: parent }   // swallow clicks so they don't close the overlay

        // ----- (decoration) dim grid background -----
        Item {
            anchors.fill: parent
            opacity: 0.22; z: 0
            Repeater {
                model: Math.floor(card.width / 40)
                Rectangle { width: 1; height: card.height; x: index * 40; color: root.cBorder }
            }
            Repeater {
                model: Math.floor(card.height / 40)
                Rectangle { height: 1; width: card.width; y: index * 40; color: root.cBorder }
            }
        }

        // ----- (decoration) corner brackets -----
        Repeater {
            model: 4
            Item {
                width: 14; height: 14; opacity: 0.55; z: 0
                x: (index === 0 || index === 2) ? 0 : (card.width - 14)
                y: (index === 0 || index === 1) ? 0 : (card.height - 14)
                property bool isRight: (index === 1 || index === 3)
                property bool isBottom: (index === 2 || index === 3)
                Rectangle { width: 14; height: 2; color: root.cSecondary; y: parent.isBottom ? 12 : 0 }
                Rectangle { width: 2; height: 14; color: root.cSecondary; x: parent.isRight ? 12 : 0 }
            }
        }

        // ----- CONTENT -----
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 30
            spacing: 12
            z: 10

            // ---- header (mirrors SYSTEM INFO) ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    width: 10; height: 10; radius: 5
                    color: root.cSecondary
                    Layout.alignment: Qt.AlignVCenter
                    SequentialAnimation on opacity {
                        running: root.shown; loops: Animation.Infinite
                        NumberAnimation { from: 0.4; to: 1; duration: 800; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1; to: 0.4; duration: 800; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    text: "󰻠"   // nerd cpu glyph
                    color: root.cSecondary
                    font.family: root.fontN; font.pixelSize: 18
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: "SYSTEM MONITOR"
                    color: root.cText
                    font.family: root.fontM; font.pixelSize: 18; font.bold: true; font.letterSpacing: 3
                    Layout.alignment: Qt.AlignVCenter
                }
                // live palette swatches (drawn from the active theme, not hard-coded)
                Row {
                    spacing: 4
                    Layout.leftMargin: 10
                    Layout.alignment: Qt.AlignVCenter
                    Repeater {
                        model: 7
                        Rectangle {
                            width: 9; height: 9; radius: 2
                            color: root.swatchAt(index)
                            border.color: root.cBorder; border.width: 1
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: "HOST"
                        color: root.cDim
                        font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1
                    }
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: (Services.SysInfoService.userName || "—") + "@" + (Services.SysInfoService.hostname || "—")
                        color: root.cSecondary
                        font.family: root.fontM; font.pixelSize: 11; font.bold: true
                    }
                }
                Text {
                    text: "ESC"
                    color: root.cDim
                    font.family: root.fontM; font.pixelSize: 9
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 8
                }
            }

            // ---- sub-header strip ----
            Text {
                Layout.fillWidth: true
                text: "REAL-TIME  //  " +
                      (Services.SysInfoService.osName || "—") + "  //  " +
                      (Services.SysInfoService.kernel || "")
                color: root.cDim
                font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

            // ---- card grid (scrollable if it ever overflows) ----
            Flickable {
                id: flick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: grid.height
                flickableDirection: Flickable.VerticalFlick

                GridLayout {
                    id: grid
                    width: flick.width
                    columns: 3
                    rowSpacing: 12
                    columnSpacing: 12

                    // ========================================================
                    // CPU_LOAD  (colSpan 3, full-width hero) — bars + readouts + per-core
                    // ========================================================
                    Rectangle {
                        Layout.columnSpan: 3
                        Layout.fillWidth: true
                        Layout.preferredHeight: 220
                        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                        border.color: root.cBorder; border.width: 1

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 16
                            spacing: 10

                            // header
                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                Rectangle { width: 8; height: 8; radius: 2; color: root.cSecondary; Layout.alignment: Qt.AlignVCenter }
                                Text { text: "CPU_LOAD"; color: root.cText
                                    font.family: root.fontM; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2 }
                                Item { Layout.fillWidth: true }
                                Text { text: Math.round(root.cpuTotalPct) + "%"; color: root.cSecondary
                                    font.family: root.fontM; font.pixelSize: 15; font.bold: true }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

                            // body: full-width bar histogram + readouts + compact per-core text
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 8

                                // bar histogram — each column = one poll sample, height = load %.
                                // Newest bar (right) = live value in accent; older bars fade back.
                                Item {
                                    id: cpuBars
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    // faint baseline so a 0% tick still reads as a graph
                                    Rectangle {
                                        anchors.left: parent.left; anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: 1; color: root.tint(root.cBorder, 0.5)
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 1
                                        Repeater {
                                            model: root._cpuBars
                                            delegate: Item {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                property bool live: index === root._cpuBars.length - 1
                                                Rectangle {
                                                    anchors.left: parent.left; anchors.right: parent.right
                                                    anchors.bottom: parent.bottom
                                                    height: parent.height * Math.min(1, Math.max(0, modelData || 0) / 100)
                                                    color: parent.live ? root.cAccent : root.cSecondary
                                                    opacity: parent.live
                                                             ? 1.0
                                                             : (0.35 + 0.65 * (index / Math.max(1, root._cpuBars.length - 1)))
                                                }
                                            }
                                        }
                                    }
                                }

                                // readouts: GHz / TEMP / THREADS  ·  AVG LOAD / BUSIEST
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 20
                                    ColumnLayout { spacing: 0
                                        Text { text: (Services.CoreEngineService.cpuGhz || 0).toFixed(2)
                                            color: root.cText; font.family: root.fontM; font.pixelSize: 16; font.bold: true }
                                        Text { text: "GHZ AVG"; color: root.cDim
                                            font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                                    }
                                    ColumnLayout { spacing: 0
                                        Text { text: Math.round(Services.ThermalService.cpuTemp || 0) + "°"
                                            color: root.tempColor(Services.ThermalService.cpuTemp || 0)
                                            font.family: root.fontM; font.pixelSize: 16; font.bold: true }
                                        Text { text: "PKG TEMP"; color: root.cDim
                                            font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                                    }
                                    ColumnLayout { spacing: 0
                                        Text { text: root.cpuThreads + "T"
                                            color: root.cText; font.family: root.fontM; font.pixelSize: 16; font.bold: true }
                                        Text { text: "THREADS"; color: root.cDim
                                            font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                                    }
                                    Item { Layout.fillWidth: true }
                                    ColumnLayout { spacing: 0
                                        Text { text: Math.round(root.cpuTotalPct) + "%"
                                            color: root.cSecondary; font.family: root.fontM; font.pixelSize: 16; font.bold: true }
                                        Text { text: "AVG LOAD"; color: root.cDim
                                            font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                                    }
                                    ColumnLayout { spacing: 0
                                        Text { text: root.cpuMaxCore + "%"
                                            color: root.cAccent; font.family: root.fontM; font.pixelSize: 16; font.bold: true }
                                        Text { text: "BUSIEST"; color: root.cDim
                                            font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                                    }
                                }

                                // per-core — compact TEXT (no boxes/bars); busiest core highlighted
                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 8
                                    rowSpacing: 3; columnSpacing: 8

                                    Repeater {
                                        model: root._perCore
                                        delegate: RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 4
                                            property bool hot: index === root.hottestCore && (modelData || 0) > 5
                                            Text { text: "C" + root.pad2(index); color: root.cDim
                                                font.family: root.fontM; font.pixelSize: 9 }
                                            Text { text: Math.round(modelData || 0) + "%"
                                                color: hot ? root.cAccent : root.cText
                                                font.family: root.fontM; font.pixelSize: 9; font.bold: hot }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // (MEMORY card moved into the compact MEMORY + STORAGE pair below)

                    // ========================================================
                    // PROCESS_MATRIX  (colSpan 2) — live top-processes table
                    // ========================================================
                    Rectangle {
                        Layout.columnSpan: 2
                        Layout.fillWidth: true
                        Layout.preferredHeight: 188
                        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                        border.color: root.cBorder; border.width: 1

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 16
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                Rectangle {
                                    width: 8; height: 8; radius: 2; color: root.cText
                                    Layout.alignment: Qt.AlignVCenter
                                    SequentialAnimation on opacity {
                                        running: root.shown; loops: Animation.Infinite
                                        NumberAnimation { from: 0.4; to: 1; duration: 1000; easing.type: Easing.InOutSine }
                                        NumberAnimation { from: 1; to: 0.4; duration: 1000; easing.type: Easing.InOutSine }
                                    }
                                }
                                Text { text: "PROCESS_MATRIX"; color: root.cText
                                    font.family: root.fontM; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2
                                    Layout.alignment: Qt.AlignVCenter }
                                Item { Layout.fillWidth: true }
                                Text { text: (Services.SystemMonitorService.processCount || 0) + " TASKS"; color: root.cDim
                                    font.family: root.fontM; font.pixelSize: 9 }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

                            // column headers
                            RowLayout {
                                Layout.fillWidth: true; spacing: 10
                                Item { Layout.preferredWidth: 14 }
                                Text { text: "PID"; color: root.cDim
                                    font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1; Layout.preferredWidth: 46 }
                                Text { text: "COMMAND"; color: root.cDim
                                    font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1; Layout.fillWidth: true }
                                Text { text: "CPU%"; color: root.cDim
                                    font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1; Layout.preferredWidth: 84 }
                                Text { text: "MEM%"; color: root.cDim
                                    font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1; Layout.preferredWidth: 84 }
                            }

                            // list
                            Flickable {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                contentWidth: width
                                contentHeight: procCol.height
                                flickableDirection: Flickable.VerticalFlick

                                ColumnLayout {
                                    id: procCol
                                    width: parent.width
                                    spacing: 2

                                    Repeater {
                                        model: Services.SystemMonitorService.processes
                                        delegate: Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 26
                                            visible: model.comm !== undefined
                                            property bool spike: (model.cpuPct || 0) > 15
                                            color: spike ? root.tint(root.cErr, 0.10) : "transparent"
                                            border.color: spike ? root.tint(root.cErr, 0.4) : "transparent"
                                            border.width: 1

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8; anchors.rightMargin: 8
                                                spacing: 10

                                                Rectangle {
                                                    width: 7; height: 7; radius: 3.5
                                                    color: root.dotColor(model.cpuPct)
                                                    Layout.alignment: Qt.AlignVCenter
                                                    Layout.preferredWidth: 14
                                                }
                                                Text { text: model.pid !== undefined ? model.pid : "—"; color: root.cDim
                                                    font.family: root.fontM; font.pixelSize: 10
                                                    Layout.preferredWidth: 46; Layout.alignment: Qt.AlignVCenter }
                                                Text { text: model.comm || "—"; color: root.cText
                                                    font.family: root.fontM; font.pixelSize: 11
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter }

                                                // CPU% bar (flat)
                                                RowLayout {
                                                    Layout.preferredWidth: 84; spacing: 6
                                                    Rectangle {
                                                        Layout.fillWidth: true; Layout.preferredHeight: 5
                                                        color: root.tint(root.cBorder, 0.6)
                                                        Rectangle {
                                                            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                                            width: parent.width * Math.min(1, Math.max(0, model.cpuPct || 0) / 30)
                                                            color: root.cSecondary
                                                            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                                        }
                                                    }
                                                    Text { text: (model.cpuPct || 0).toFixed(1); color: root.cText
                                                        font.family: root.fontM; font.pixelSize: 10; font.bold: true
                                                        Layout.preferredWidth: 30; horizontalAlignment: Text.AlignRight }
                                                }

                                                // MEM% bar (flat)
                                                RowLayout {
                                                    Layout.preferredWidth: 84; spacing: 6
                                                    Rectangle {
                                                        Layout.fillWidth: true; Layout.preferredHeight: 5
                                                        color: root.tint(root.cBorder, 0.6)
                                                        Rectangle {
                                                            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                                            width: parent.width * Math.min(1, Math.max(0, model.memPct || 0) / 20)
                                                            color: root.cAccent
                                                            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                                        }
                                                    }
                                                    Text { text: (model.memPct || 0).toFixed(1); color: root.cText
                                                        font.family: root.fontM; font.pixelSize: 10; font.bold: true
                                                        Layout.preferredWidth: 30; horizontalAlignment: Text.AlignRight }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ========================================================
                    // MEMORY + STORAGE  — compact side-by-side pair (col 3)
                    // ========================================================
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 188

                        RowLayout {
                            anchors.fill: parent
                            spacing: 12

                            // ---- MEMORY (compact) ----
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                                border.color: root.cBorder; border.width: 1

                                ColumnLayout {
                                    anchors.fill: parent; anchors.margins: 12
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true; spacing: 6
                                        Rectangle { width: 7; height: 7; radius: 2; color: root.cAccent; Layout.alignment: Qt.AlignVCenter }
                                        Text { text: "MEMORY"; color: root.cText
                                            font.family: root.fontM; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1 }
                                        Item { Layout.fillWidth: true }
                                        Text { text: Math.round(Services.CoreEngineService.ramPct || 0) + "%"; color: root.cAccent
                                            font.family: root.fontM; font.pixelSize: 11; font.bold: true }
                                    }
                                    Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

                                    // RAM
                                    ColumnLayout { Layout.fillWidth: true; spacing: 3
                                        Text { text: root.fmtGB(Services.CoreEngineService.ramUsedGB) + " / " + root.fmtGB(Services.CoreEngineService.ramTotalGB)
                                            color: root.cText; font.family: root.fontM; font.pixelSize: 11; font.bold: true
                                            Layout.alignment: Qt.AlignHCenter }
                                        Text { text: "RAM"; color: root.cDim
                                            font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1
                                            Layout.alignment: Qt.AlignHCenter }
                                        Rectangle {
                                            Layout.fillWidth: true; Layout.preferredHeight: 6
                                            color: root.tint(root.cBorder, 0.6)
                                            Rectangle {
                                                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                                width: parent.width * Math.min(1, Math.max(0, Services.CoreEngineService.ramPct || 0) / 100)
                                                color: root.cAccent
                                                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                            }
                                        }
                                    }

                                    Item { Layout.fillHeight: true }

                                    // SWAP
                                    ColumnLayout { Layout.fillWidth: true; spacing: 3
                                        RowLayout { Layout.fillWidth: true
                                            Text { text: "SWAP"; color: root.cDim
                                                font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                                            Item { Layout.fillWidth: true }
                                            Text { text: Math.round(((Services.CoreEngineService.swapUsedGB || 0) /
                                                  Math.max(0.001, Services.CoreEngineService.swapTotalGB || 1)) * 100) + "%"
                                                color: root.cWarn; font.family: root.fontM; font.pixelSize: 9; font.bold: true }
                                        }
                                        Rectangle {
                                            Layout.fillWidth: true; Layout.preferredHeight: 5
                                            color: root.tint(root.cBorder, 0.6)
                                            Rectangle {
                                                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                                width: parent.width * Math.min(1, Math.max(0, (Services.CoreEngineService.swapUsedGB || 0) /
                                                      Math.max(0.001, Services.CoreEngineService.swapTotalGB || 1)))
                                                color: root.cWarn
                                                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                            }
                                        }
                                    }
                                }
                            }

                            // ---- STORAGE (compact) ----
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                                border.color: root.cBorder; border.width: 1

                                ColumnLayout {
                                    anchors.fill: parent; anchors.margins: 12
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true; spacing: 6
                                        Rectangle { width: 7; height: 7; radius: 2; color: root.cSecondary; Layout.alignment: Qt.AlignVCenter }
                                        Text { text: "STORAGE"; color: root.cText
                                            font.family: root.fontM; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1 }
                                        Item { Layout.fillWidth: true }
                                    }
                                    Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

                                    // disk
                                    ColumnLayout { Layout.fillWidth: true; spacing: 4
                                        Text { text: Math.round(root._primaryDisk ? (root._primaryDisk.pct || 0) : 0) + "%"
                                            color: root.cText; font.family: root.fontM; font.pixelSize: 17; font.bold: true
                                            Layout.alignment: Qt.AlignHCenter }
                                        Text { text: root.mountLabel(root._primaryDisk ? root._primaryDisk.mount : null).toUpperCase()
                                            color: root.cSecondary; font.family: root.fontM; font.pixelSize: 9; font.bold: true
                                            Layout.alignment: Qt.AlignHCenter }
                                        Rectangle {
                                            Layout.fillWidth: true; Layout.preferredHeight: 6
                                            color: root.tint(root.cBorder, 0.6)
                                            Rectangle {
                                                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                                width: parent.width * Math.min(1, Math.max(0, root._primaryDisk ? (root._primaryDisk.pct || 0) : 0) / 100)
                                                color: root.diskColor(root._primaryDisk ? (root._primaryDisk.pct || 0) : 0)
                                                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                                Behavior on color { ColorAnimation { duration: 200 } }
                                            }
                                        }
                                        Text { text: root._diskCount + " vol  ·  R " + (Services.SystemMonitorService.diskReadRate || 0).toFixed(1) + "M"
                                            color: root.cDim; font.family: root.fontM; font.pixelSize: 8
                                            Layout.alignment: Qt.AlignHCenter }
                                    }

                                    Item { Layout.fillHeight: true }

                                    // GPU integrity (compact, only if a GPU is present)
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 3
                                        visible: Services.GpuService.present
                                        RowLayout { Layout.fillWidth: true
                                            Text { text: "GPU"; color: root.cDim
                                                font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                                            Item { Layout.fillWidth: true }
                                            Text { text: Math.round(Services.GpuService.temp || 0) + "°"
                                                color: root.tempColor(Services.GpuService.temp || 0)
                                                font.family: root.fontM; font.pixelSize: 9; font.bold: true }
                                        }
                                        RowLayout { Layout.fillWidth: true
                                            Text { text: "FAN"; color: root.cDim
                                                font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                                            Item { Layout.fillWidth: true }
                                            Text { text: Math.round(Services.GpuService.fanPct || 0) + "%"
                                                color: root.cDim; font.family: root.fontM; font.pixelSize: 9; font.bold: true }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ========================================================
                    // NETWORK_IO  (colSpan 3 strip) — sparkline + rates
                    // ========================================================
                    Rectangle {
                        Layout.columnSpan: 3
                        Layout.fillWidth: true
                        Layout.preferredHeight: 84
                        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                        border.color: root.cBorder; border.width: 1

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 16
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                Rectangle {
                                    width: 8; height: 8; radius: 4; color: root.cInfo
                                    Layout.alignment: Qt.AlignVCenter
                                    SequentialAnimation on opacity {
                                        running: root.shown; loops: Animation.Infinite
                                        NumberAnimation { from: 0.35; to: 1; duration: 900; easing.type: Easing.InOutSine }
                                        NumberAnimation { from: 1; to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                                    }
                                }
                                Text { text: "NETWORK_IO"; color: root.cText
                                    font.family: root.fontM; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2 }
                                Item { Layout.fillWidth: true }
                                Text { text: Services.NetworkService.ipAddress || "—"; color: root.cInfo
                                    font.family: root.fontM; font.pixelSize: 9 }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 20

                                // bar histogram — each column = one poll sample,
                                // height = download rate (scaled to rolling max).
                                Item {
                                    id: netBars
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    Rectangle {
                                        anchors.left: parent.left; anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: 1; color: root.tint(root.cBorder, 0.5)
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 1
                                        Repeater {
                                            model: root._netBars
                                            delegate: Item {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                property bool live: index === root._netBars.length - 1
                                                Rectangle {
                                                    anchors.left: parent.left; anchors.right: parent.right
                                                    anchors.bottom: parent.bottom
                                                    height: parent.height * Math.min(1, Math.max(0, modelData || 0) / Math.max(1, root._netMax))
                                                    color: parent.live ? root.cAccent : root.cInfo
                                                    opacity: parent.live
                                                             ? 1.0
                                                             : (0.35 + 0.65 * (index / Math.max(1, root._netBars.length - 1)))
                                                }
                                            }
                                        }
                                    }
                                }

                                ColumnLayout { spacing: 0
                                    Text { text: "↓ DOWN"; color: root.cDim
                                        font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                                    Text { text: root.fmtRate(Services.SystemMonitorService.netDownRate); color: root.cInfo
                                        font.family: root.fontM; font.pixelSize: 14; font.bold: true }
                                }
                                ColumnLayout { spacing: 0
                                    Text { text: "↑ UP"; color: root.cDim
                                        font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                                    Text { text: root.netUpText(); color: root.cAccent
                                        font.family: root.fontM; font.pixelSize: 14; font.bold: true }
                                }
                            }
                        }
                    }
                }
            }

            // ---- footer (mirrors SYSTEM INFO) ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                opacity: 0.7
                RowLayout { spacing: 6
                    Rectangle { width: 6; height: 6; radius: 3; color: root.cSuccess; Layout.alignment: Qt.AlignVCenter }
                    Text { text: "TELEMETRY OK"; color: root.cDim
                        font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                }
                RowLayout { spacing: 6
                    Rectangle { width: 6; height: 6; radius: 3; color: root.cSuccess; Layout.alignment: Qt.AlignVCenter }
                    Text { text: "POLL ACTIVE"; color: root.cDim
                        font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                }
                Item { Layout.fillWidth: true }
                Text { text: "[ " + (Services.SysInfoService.hostname || "host") + " ]"
                    color: root.cDim; font.family: root.fontM; font.pixelSize: 9 }
                Text { text: root.clockText; color: root.cSecondary
                    font.family: root.fontM; font.pixelSize: 9; font.bold: true }
            }
        }
    }

    // ---- live clock (1s, runs only while shown) ----
    Timer {
        id: clockTimer
        interval: 1000
        repeat: true
        running: root.shown
        onTriggered: {
            var d = new Date()
            var hh = d.getHours(); if (hh < 10) hh = "0" + hh
            var mm = d.getMinutes(); if (mm < 10) mm = "0" + mm
            var ss = d.getSeconds(); if (ss < 10) ss = "0" + ss
            root.clockText = hh + ":" + mm + ":" + ss
        }
        triggeredOnStart: true
    }
}
