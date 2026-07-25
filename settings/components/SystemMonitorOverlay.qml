// =============================================================================
// SystemMonitorOverlay.qml — fullscreen tactical-HUD system monitor
// =============================================================================
// Realtime fullscreen-toggleable overlay matching the tactical-HUD mockup: a
// 1280x800 centred card over a dim click-to-close backdrop, split into three
// rows — CPU telemetry + load history (1), the process subsystem with a live
// process table (2), and a memory / storage / network strip (3). All accents
// are Config.ThemeConfig.colors.* tokens so the whole panel recolours with the
// live theme; all data is bound to the always-on CoreEngine / Thermal /
// SysInfo / Network services plus the on-demand SystemMonitorService, whose
// `active` flag is driven from open()/close() so its polling only runs while
// the overlay is shown. Toggled via the 'systemMonitor' IPC handler in
// settings/shell.qml, which calls toggle(). Esc / click-outside also close.
//
// Shell mirrors FastfetchOverlay (shown + open/close/toggle, hideTimer, dim
// backdrop, dim grid + corner brackets); bars/sparks reuse CoreBar + HudSpark.
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

    visible: false
    function open() {
        visible = true
        shown = true
        Services.SystemMonitorService.active = true
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

    Keys.onEscapePressed: root.close()
    onShownChanged: if (!shown) hideTimer.restart()
    Timer { id: hideTimer; interval: 220; onTriggered: if (!root.shown) root.visible = false }

    // ---- palette (every accent is a live ThemeConfig token) ----
    readonly property color cBg:        Config.ThemeConfig.colors.background
    readonly property color cSurfaceV:  Config.ThemeConfig.colors.surfaceVariant
    readonly property color cText:      Config.ThemeConfig.colors.text
    readonly property color cDim:       Config.ThemeConfig.colors.textDim
    readonly property color cBorder:    Config.ThemeConfig.colors.border
    readonly property color cPrimary:   Config.ThemeConfig.colors.primary
    readonly property color cSecondary: Config.ThemeConfig.colors.secondary
    readonly property color cWarn:      Config.ThemeConfig.colors.warning
    readonly property color cErr:       Config.ThemeConfig.colors.error

    // ---- fonts ----
    readonly property string fontD: Config.SettingsConfig.fontFamily   // display numbers
    readonly property string fontM: Config.ControlConfig.fontMono      // mono labels

    readonly property int cardW: 1280
    readonly property int cardH: 800

    // ---- process-table column widths (shared by header + rows) ----
    readonly property int colPid:  56
    readonly property int colComm: 140
    readonly property int colUser: 80
    readonly property int colMem:  64
    readonly property int colCpu:  150

    // ---- helpers ----
    // alpha-tint a theme token (kept as a color so .r/.g/.b are valid)
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    // cool -> warm -> hot severity colour (CoreOverviewPane idiom)
    function tempTier(t) {
        if (t >= 75) return cErr
        if (t >= 55) return cWarn
        return cSecondary
    }
    function pad2(n) { return ("0" + n).slice(-2) }
    // bytes/sec -> human rate (B/s, KiB/s, MiB/s)
    function fmtRate(b) {
        if (!b || b < 0) return "0 B/s"
        if (b < 1024) return Math.round(b) + " B/s"
        if (b < 1048576) return (b / 1024).toFixed(1) + " KiB/s"
        return (b / 1048576).toFixed(2) + " MiB/s"
    }
    function fmtGB(g) { return (g || 0).toFixed(1) + "G" }
    // trim long CPU model strings for the card sub-header
    function shortModel(s) {
        if (!s) return "—"
        return s.replace(/\(R\)|\(TM\)|CPU|Processor/gi, "").replace(/\s+/g, " ").trim()
    }

    // SMT-aware core/thread counts (coreCount is logical cores = threads)
    readonly property int cpuThreads: Services.SystemMonitorService.coreCount || 0
    readonly property int cpuCores:   Math.round(root.cpuThreads / 2)

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
    // CENTERED CARD (1280x800)
    // =========================================================================
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: root.cardW; height: root.cardH
        color: root.cBg
        border.color: root.cBorder
        border.width: 1
        clip: true
        opacity: root.shown ? 1.0 : 0.0
        scale: root.shown ? 1.0 : 0.96
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent }   // swallow clicks so they don't close the overlay

        // ----- (decoration) dim grid background -----
        Item {
            anchors.fill: parent; opacity: 0.18; z: 0
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
                width: 14; height: 14; opacity: 0.6; z: 0
                x: (index === 0 || index === 2) ? 0 : (card.width - 14)
                y: (index === 0 || index === 1) ? 0 : (card.height - 14)
                property bool isRight:  (index === 1 || index === 3)
                property bool isBottom: (index === 2 || index === 3)
                Rectangle { width: 14; height: 2; color: root.cSecondary; y: parent.isBottom ? 12 : 0 }
                Rectangle { width: 2;  height: 14; color: root.cSecondary; x: parent.isRight  ? 12 : 0 }
            }
        }

        // ----- CONTENT -----
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 12
            z: 10

            // ---- title bar ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle { width: 10; height: 10; radius: 2; color: root.cPrimary; Layout.alignment: Qt.AlignVCenter }
                Text {
                    text: "SYSTEM_MONITOR"
                    color: root.cText
                    font.family: root.fontM; font.pixelSize: 13; font.bold: true; font.letterSpacing: 3
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: "// REALTIME TELEMETRY"
                    color: root.cDim
                    font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1
                    Layout.alignment: Qt.AlignVCenter
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "UPTIME " + (Services.SysInfoService.uptime || "—")
                    color: root.cDim
                    font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: "ESC"
                    color: root.cDim
                    font.family: root.fontM; font.pixelSize: 9
                    Layout.alignment: Qt.AlignVCenter; Layout.leftMargin: 8
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

            // ===============================================================
            // ROW 1 — CPU telemetry + load history (~28% height)
            // ===============================================================
            GridLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: root.cardH * 0.28
                columns: 12
                rowSpacing: 10
                columnSpacing: 10

                // ---- 01_CPU_TELEMETRY (colSpan 8) ---- CoreEngineService + Thermal/SystemMonitor
                Rectangle {
                    Layout.columnSpan: 8
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.tint(root.cSurfaceV, 0.30)
                    border.color: root.cBorder; border.width: 1

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 14
                        spacing: 8

                        // header
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Text {
                                text: "01_CPU_TELEMETRY"
                                color: root.cPrimary
                                font.family: root.fontM; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root.shortModel(Services.SystemMonitorService.cpuModel)
                                      + "  |  " + (root.cpuThreads > 0 ? (root.cpuCores + "C/" + root.cpuThreads + "T") : "—")
                                color: root.cDim
                                font.family: root.fontM; font.pixelSize: 9
                                elide: Text.ElideRight; Layout.maximumWidth: 440
                            }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

                        // per-core grid (~8 columns, auto-flow)
                        GridLayout {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            columns: 8
                            rowSpacing: 6; columnSpacing: 6

                            Repeater {
                                model: Services.CoreEngineService.perCoreLoad
                                delegate: Rectangle {
                                    id: coreTile
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    color: Qt.rgba(0, 0, 0, 0.35)
                                    border.color: root.cBorder; border.width: 1
                                    // guard every array index so a missing sample never breaks layout
                                    property real coreLoad: modelData || 0
                                    property real coreTemp: Services.SystemMonitorService.perCoreTemp[index] || 0

                                    ColumnLayout {
                                        anchors.fill: parent; anchors.margins: 5; spacing: 2
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { text: "C" + root.pad2(index + 1); color: root.cDim
                                                font.family: root.fontM; font.pixelSize: 8; font.bold: true }
                                            Item { Layout.fillWidth: true }
                                            Text { text: Math.round(coreTile.coreTemp) + "°"
                                                color: coreTile.coreTemp > 0 ? root.tempTier(coreTile.coreTemp) : root.cDim
                                                font.family: root.fontM; font.pixelSize: 8; font.bold: true }
                                        }
                                        CoreBar { Layout.fillWidth: true; barHeight: 3
                                            value: coreTile.coreLoad; barColor: root.cPrimary }
                                        Text { text: Math.round(coreTile.coreLoad) + "%"; color: root.cPrimary
                                            font.family: root.fontM; font.pixelSize: 8; font.bold: true }
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- 02_LOAD_HISTORY (colSpan 4) ---- CoreEngineService.cpuUsage
                Rectangle {
                    Layout.columnSpan: 4
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.tint(root.cSurfaceV, 0.30)
                    border.color: root.cBorder; border.width: 1

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 14
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "02_LOAD_HISTORY"
                                color: root.cSecondary
                                font.family: root.fontM; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: Services.SysInfoService.uptime || "—"
                                color: root.cDim
                                font.family: root.fontM; font.pixelSize: 9
                            }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

                        HudSpark {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            value: Services.CoreEngineService.cpuUsage
                            max: 100
                            accent: root.cSecondary
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "AVG"; color: root.cDim
                                font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                            Text { text: Math.round(Services.CoreEngineService.cpuUsage) + "%"; color: root.cSecondary
                                font.family: root.fontM; font.pixelSize: 9; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text { text: Services.CoreEngineService.cpuGhz.toFixed(2) + " GHz"; color: root.cDim
                                font.family: root.fontM; font.pixelSize: 8 }
                        }
                    }
                }
            }

            // ===============================================================
            // ROW 2 — process subsystem (fills remaining height)
            // ===============================================================
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: root.tint(root.cSurfaceV, 0.30)
                border.color: root.cBorder; border.width: 1

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 14
                    spacing: 8

                    // header  (SystemMonitorService.processCount + static legend)
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Rectangle { width: 8; height: 8; color: root.cPrimary; Layout.alignment: Qt.AlignVCenter }
                        Text {
                            text: "03_PROCESS_SUBSYSTEM"
                            color: root.cPrimary
                            font.family: root.fontM; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Item { Layout.fillWidth: true }
                        Text { text: "TASKS:"; color: root.cDim
                            font.family: root.fontM; font.pixelSize: 9; Layout.alignment: Qt.AlignVCenter }
                        Text { text: (Services.SystemMonitorService.processCount || 0)
                            color: root.cSecondary
                            font.family: root.fontM; font.pixelSize: 9; font.bold: true; Layout.alignment: Qt.AlignVCenter }
                        Text { text: "·  SORT:"; color: root.cDim
                            font.family: root.fontM; font.pixelSize: 9; Layout.alignment: Qt.AlignVCenter; Layout.leftMargin: 6 }
                        Text { text: "CPU%"; color: root.cWarn
                            font.family: root.fontM; font.pixelSize: 9; font.bold: true; Layout.alignment: Qt.AlignVCenter }
                        Text { text: "·  NODE: CORE_X_09"; color: root.cDim
                            font.family: root.fontM; font.pixelSize: 9; Layout.alignment: Qt.AlignVCenter; Layout.leftMargin: 6 }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

                    // column header row (widths mirror the row layout below)
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text { text: "PID"; color: root.cDim
                            font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                            Layout.preferredWidth: root.colPid }
                        Text { text: "PROGRAM"; color: root.cDim
                            font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                            Layout.preferredWidth: root.colComm }
                        Text { text: "COMMAND_STRING"; color: root.cDim
                            font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                            Layout.fillWidth: true }
                        Text { text: "USER"; color: root.cDim
                            font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                            Layout.preferredWidth: root.colUser }
                        Text { text: "MEM%"; color: root.cDim
                            font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                            Layout.preferredWidth: root.colMem; horizontalAlignment: Text.AlignRight }
                        Text { text: "CPU%"; color: root.cDim
                            font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                            Layout.preferredWidth: root.colCpu }
                    }

                    // scrollable process list  (SystemMonitorService.processes)
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
                                    Layout.preferredHeight: 24
                                    color: index === 0
                                        ? root.tint(root.cPrimary, 0.10)
                                        : "transparent"
                                    visible: model.comm !== undefined

                                    // index-0 highlight: 3px primary left accent
                                    Rectangle {
                                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                        width: 3; color: root.cPrimary; visible: index === 0
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8; anchors.rightMargin: 4
                                        spacing: 8

                                        Text { text: model.pid !== undefined ? model.pid : "—"; color: root.cDim
                                            font.family: root.fontM; font.pixelSize: 9
                                            Layout.preferredWidth: root.colPid; verticalAlignment: Text.AlignVCenter }

                                        Text { text: model.comm || "—"; color: root.cSecondary
                                            font.family: root.fontM; font.pixelSize: 9; font.bold: index === 0
                                            elide: Text.ElideRight
                                            Layout.preferredWidth: root.colComm; verticalAlignment: Text.AlignVCenter }

                                        Text { text: model.args || ""; color: root.cDim
                                            font.family: root.fontM; font.pixelSize: 9
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true; verticalAlignment: Text.AlignVCenter }

                                        Text { text: model.user || "—"
                                            color: (model.user === "root") ? root.cWarn : root.cDim
                                            font.family: root.fontM; font.pixelSize: 9
                                            Layout.preferredWidth: root.colUser; verticalAlignment: Text.AlignVCenter }

                                        Text { text: Math.round(model.memPct || 0) + "%"; color: root.cText
                                            font.family: root.fontM; font.pixelSize: 9
                                            Layout.preferredWidth: root.colMem
                                            horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter }

                                        RowLayout {
                                            Layout.preferredWidth: root.colCpu; spacing: 6
                                            CoreBar { Layout.preferredWidth: 96; barHeight: 3
                                                value: model.cpuPct || 0; barColor: root.cPrimary }
                                            Text { text: Math.round(model.cpuPct || 0) + "%"; color: root.cPrimary
                                                font.family: root.fontM; font.pixelSize: 9; font.bold: true }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // footer keybinds
                    Rectangle { Layout.fillWidth: true; height: 1
                        color: root.tint(root.cBorder, 0.5) }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 18
                        RowLayout { spacing: 4
                            Text { text: "[F1]"; color: root.tint(root.cSecondary, 0.7)
                                font.family: root.fontM; font.pixelSize: 8 }
                            Text { text: "HELP"; color: root.cDim
                                font.family: root.fontM; font.pixelSize: 8 } }
                        RowLayout { spacing: 4
                            Text { text: "[F2]"; color: root.tint(root.cSecondary, 0.7)
                                font.family: root.fontM; font.pixelSize: 8 }
                            Text { text: "SETUP"; color: root.cDim
                                font.family: root.fontM; font.pixelSize: 8 } }
                        RowLayout { spacing: 4
                            Text { text: "[F3]"; color: root.tint(root.cSecondary, 0.7)
                                font.family: root.fontM; font.pixelSize: 8 }
                            Text { text: "KILL"; color: root.cDim
                                font.family: root.fontM; font.pixelSize: 8 } }
                        RowLayout { spacing: 4
                            Text { text: "[F4]"; color: root.tint(root.cSecondary, 0.7)
                                font.family: root.fontM; font.pixelSize: 8 }
                            Text { text: "FILTER"; color: root.cDim
                                font.family: root.fontM; font.pixelSize: 8 } }
                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // ===============================================================
            // ROW 3 — memory / storage / network (~22% height)
            // ===============================================================
            GridLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: root.cardH * 0.22
                columns: 3
                rowSpacing: 10
                columnSpacing: 10

                // ---- 04_MEMORY_MAP ---- CoreEngineService RAM/SWAP + ramCachedGB
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: root.tint(root.cSurfaceV, 0.30)
                    border.color: root.cBorder; border.width: 1

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 6

                        Text { text: "04_MEMORY_MAP"; color: root.cPrimary
                            font.family: root.fontM; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2 }
                        Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

                        // PHYS_RAM
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "PHYS_RAM"; color: root.cDim
                                font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                            Item { Layout.fillWidth: true }
                            Text { text: root.fmtGB(Services.CoreEngineService.ramTotalGB); color: root.cText
                                font.family: root.fontM; font.pixelSize: 9; font.bold: true }
                        }
                        // segmented RAM bar: used (primary) + cached (secondary-dim) adjacent in one track
                        Item {
                            id: ramBar
                            Layout.fillWidth: true; Layout.preferredHeight: 10
                            readonly property real usedFrac: Math.max(0, Math.min(100, Services.CoreEngineService.ramPct)) / 100
                            readonly property real cachedFrac: Services.CoreEngineService.ramTotalGB > 0
                                ? Math.max(0, Services.SystemMonitorService.ramCachedGB / Services.CoreEngineService.ramTotalGB)
                                : 0
                            Rectangle { anchors.fill: parent; color: root.cSurfaceV }   // track
                            Rectangle {                                                       // used segment
                                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                width: parent.width * Math.min(1, ramBar.usedFrac); color: root.cPrimary
                            }
                            Rectangle {                                                       // cached segment (adjacent)
                                anchors.top: parent.top; anchors.bottom: parent.bottom
                                x: parent.width * Math.min(1, ramBar.usedFrac)
                                width: Math.min(parent.width - parent.width * Math.min(1, ramBar.usedFrac),
                                                parent.width * ramBar.cachedFrac)
                                color: root.tint(root.cSecondary, 0.45)
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "USED " + root.fmtGB(Services.CoreEngineService.ramUsedGB); color: root.cDim
                                font.family: root.fontM; font.pixelSize: 8 }
                            Item { Layout.fillWidth: true }
                            Text { text: Math.round(Services.CoreEngineService.ramPct) + "%"; color: root.cPrimary
                                font.family: root.fontM; font.pixelSize: 8; font.bold: true }
                        }

                        // SWAP_IO
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "SWAP_IO"; color: root.cDim
                                font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                            Item { Layout.fillWidth: true }
                            Text { text: root.fmtGB(Services.CoreEngineService.swapTotalGB); color: root.cText
                                font.family: root.fontM; font.pixelSize: 9 }
                        }
                        CoreBar { Layout.fillWidth: true; barHeight: 6
                            value: Services.CoreEngineService.swapPct; barColor: root.cWarn }
                        Item { Layout.fillHeight: true }
                    }
                }

                // ---- 05_STORAGE_IO ---- CoreEngineService.diskPct + diskReadRate
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: root.tint(root.cSurfaceV, 0.30)
                    border.color: root.cBorder; border.width: 1

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 6

                        Text { text: "05_STORAGE_IO"; color: root.cSecondary
                            font.family: root.fontM; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2 }
                        Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "/ROOT (NVME0)"; color: root.cDim
                                font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                            Item { Layout.fillWidth: true }
                            Text { text: Math.round(Services.CoreEngineService.diskPct) + "%"; color: root.cSecondary
                                font.family: root.fontM; font.pixelSize: 9; font.bold: true }
                        }
                        CoreBar { Layout.fillWidth: true; barHeight: 6
                            value: Services.CoreEngineService.diskPct; barColor: root.cSecondary }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "READ"; color: root.cDim
                                font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                            Item { Layout.fillWidth: true }
                            Text { text: (Services.SystemMonitorService.diskReadRate || 0).toFixed(1) + " MiB/s"
                                color: root.cWarn
                                font.family: root.fontM; font.pixelSize: 9; font.bold: true }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }

                // ---- 06_NETWORK_SYNC ---- netDownRate/netUpRate + ipAddress
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: root.tint(root.cSurfaceV, 0.30)
                    border.color: root.cBorder; border.width: 1

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 6

                        Text { text: "06_NETWORK_SYNC"; color: root.cWarn
                            font.family: root.fontM; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2 }
                        Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 16
                            ColumnLayout { spacing: 0
                                Text { text: "DOWN"; color: root.cDim
                                    font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                                Text { text: root.fmtRate(Services.SystemMonitorService.netDownRate); color: root.cPrimary
                                    font.family: root.fontD; font.pixelSize: 16; font.bold: true }
                            }
                            ColumnLayout { spacing: 0
                                Text { text: "UP"; color: root.cDim
                                    font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                                Text { text: root.fmtRate(Services.SystemMonitorService.netUpRate); color: root.cWarn
                                    font.family: root.fontD; font.pixelSize: 16; font.bold: true }
                            }
                            Item { Layout.fillWidth: true }
                        }

                        // live throughput sparkline (self-sampling HudSpark)
                        HudSpark {
                            Layout.fillWidth: true; Layout.preferredHeight: 26
                            value: Services.SystemMonitorService.netDownRate
                            max: 1048576   // 1 MiB
                            accent: root.cWarn
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: Services.NetworkService.ipAddress || "—"; color: root.cDim
                                font.family: root.fontM; font.pixelSize: 8 }
                            Item { Layout.fillWidth: true }
                            Text { text: "--ms"; color: root.cPrimary
                                font.family: root.fontM; font.pixelSize: 8; font.bold: true }
                        }
                    }
                }
            }
        }
    }
}
