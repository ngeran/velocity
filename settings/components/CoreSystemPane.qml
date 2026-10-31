// =============================================================================
// CoreSystemPane.qml — SYSTEM: digital instrument cluster (HUD rebuild)
// =============================================================================
// The mock's tactical cluster: pure-black panel, 32px engineer's grid
// backdrop, amber/cyan telemetry (HudConfig tokens — fixed, theme-independent),
// hairline dividers between bands (not floating cards). Top to bottom:
//   [A] header rail   SYSTEM / TELEMETRY · DIGITAL INSTRUMENT CLUSTER · ● LIVE
//   [B] load band     50-segment LED CPU meter, midpoint tick, 0/50/100 axis
//   [C] hero row      GPU (dial + sub-engines + VRAM) | MEM & CPU (pools)
//   [D] LCD band      embedded DeepCool Mystique controller (LcdControllerPanel)
//   [E] precision     CPU TEMP · PER-CORE · STORAGE · ENGINE quarters
//   [F] footer rail   LOCAL TELEMETRY / sample · UPDATED Ns AGO
// Anchored rows only — no GridLayout spans (span-collapse law). Every
// instrument keeps a fixed slot; a missing sensor renders an em dash and never
// shifts its neighbours.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Rectangle {
    id: root
    radius: 0
    color: "transparent"          // the HUD card's #000 shows through
    border.color: "transparent"
    clip: true

    readonly property var m: Services.HostBridge.metrics

    readonly property int coreCount: Math.max(1, m.perCoreLoad.length)

    // HUD tier colors (fixed — replaces ThemeConfig.tierColor in this pane).
    function loadTier(v) { return v >= 85 ? Config.HudConfig.red : Config.HudConfig.amber }
    function tempTier(t) { return t >= 90 ? Config.HudConfig.red : t >= 75 ? Config.HudConfig.amber : Config.HudConfig.cyan }
    function diskTier(p) { return p >= 85 ? Config.HudConfig.red : Config.HudConfig.amber }
    function driveLabel(mount) { return mount === "/" ? "SYSTEM" : (mount.split("/").pop() || mount) }
    // Hoisted to a property (not an inline-literal model): Repeater delegates
    // over literal arrays have hit the singleton-not-ready init trap before.
    readonly property var engineRows: [
        { k: "COOLANT", v: m.coolantAvailable ? m.coolantTemp.toFixed(0) + "°C" : "—",
          c: m.coolantAvailable ? tempTier(m.coolantTemp) : Config.HudConfig.textFaint },
        { k: "NVME", v: m.nvmeTemp > 0 ? m.nvmeTemp.toFixed(0) + "°C" : "—",
          c: m.nvmeTemp > 0 ? tempTier(m.nvmeTemp) : Config.HudConfig.textFaint },
        { k: "GPU CLK", v: m.clockMHz > 0 ? (m.clockMHz / 1000).toFixed(2) + " GHZ" : "—",
          c: Config.HudConfig.cyan }
    ]

    // ── [F] "UPDATED Ns AGO" — resets whenever live telemetry ticks ────────
    readonly property string _sig: m.cpuUsage.toFixed(3)
    property int _agoSec: 0
    on_SigChanged: _agoSec = 0
    Timer { interval: 1000; repeat: true; running: root.visible; onTriggered: root._agoSec++ }

    onVisibleChanged: if (visible) m.refreshUptime()

    // ── shared micro-typography ────────────────────────────────────────────
    component Eyebrow: Text {
        color: Config.HudConfig.textFaint
        font.family: Config.HudConfig.fontUi
        font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.4
    }
    component Micro: Text {
        color: Config.HudConfig.textDim
        font.family: Config.HudConfig.fontData
        font.pixelSize: 9
    }
    component HDivider: Rectangle { color: Config.HudConfig.borderHi; height: 1; Layout.fillWidth: true }
    component VDivider: Rectangle { color: Config.HudConfig.borderHi; width: 1; Layout.fillHeight: true }

    // mini stat cell (label over value) for the dial-side engine grid
    component StatCell: ColumnLayout {
        id: sc
        property string label: ""
        property string value: "—"
        property color accent: Config.HudConfig.textBody
        spacing: 1
        Text { text: sc.label
            color: Config.HudConfig.textFaint
            font.family: Config.HudConfig.fontUi; font.pixelSize: 7; font.bold: true; font.letterSpacing: 1.2 }
        Text { text: sc.value
            color: sc.accent
            font.family: Config.HudConfig.fontData; font.pixelSize: 12; font.bold: true
            elide: Text.ElideRight; Layout.fillWidth: true }
    }
    // GPU sub-engine row (dmon): label · meter · %/IDLE
    component SubEngine: RowLayout {
        id: se
        property string label: ""
        property real value: 0
        spacing: 8
        Layout.fillWidth: true
        Text { text: se.label; Layout.preferredWidth: 66
            color: Config.HudConfig.textDim
            font.family: Config.HudConfig.fontData; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.0 }
        HudMeterBar { Layout.fillWidth: true; Layout.maximumWidth: 200
            value: se.value; fill: Config.HudConfig.cyan; barHeight: 4 }
        Text { text: se.value > 0 ? Math.round(se.value) + "%" : "IDLE"
            Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight
            color: se.value > 0 ? Config.HudConfig.textBody : Config.HudConfig.textFaint
            font.family: Config.HudConfig.fontData; font.pixelSize: 8; font.bold: true }
    }
    // memory-pool row inside the pools well
    component PoolRow: RowLayout {
        id: pr
        property string label: ""
        property real giB: 0
        property string note: ""
        spacing: 8
        Layout.fillWidth: true
        Text { text: pr.label; Layout.preferredWidth: 80
            color: Config.HudConfig.textDim
            font.family: Config.HudConfig.fontData; font.pixelSize: 8; font.bold: true; font.letterSpacing: 0.8 }
        Text { text: pr.note !== "" ? pr.note : pr.giB.toFixed(1) + " G"
            Layout.preferredWidth: 66; horizontalAlignment: Text.AlignRight
            color: Config.HudConfig.textBody
            font.family: Config.HudConfig.fontData; font.pixelSize: 9; font.bold: true }
        HudMeterBar { Layout.fillWidth: true; value: pr.giB
            maximum: root.m.ramTotalGB > 0 ? root.m.ramTotalGB : 1
            fill: Config.HudConfig.cyan; barHeight: 3 }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ═════════════════════════════════════════════════════════════════
        // [A] HEADER RAIL — identity · cluster title · live status
        // ═════════════════════════════════════════════════════════════════
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 30

            Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                text: "SYSTEM / TELEMETRY"
                color: Config.HudConfig.textMid
                font.family: Config.HudConfig.fontData; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.6 }
            Text { anchors.centerIn: parent
                text: "DIGITAL INSTRUMENT CLUSTER"
                color: Config.HudConfig.textFaint
                font.family: Config.HudConfig.fontData; font.pixelSize: 8; font.letterSpacing: 2.4 }
            RowLayout { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: Config.HudConfig.amber
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.3; duration: 1200 }
                        NumberAnimation { from: 0.3; to: 1.0; duration: 1200 }
                    }
                }
                Text { text: "LIVE"
                    color: Config.HudConfig.amber
                    font.family: Config.HudConfig.fontData; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.6 }
            }
        }
        HDivider { }

        // ═════════════════════════════════════════════════════════════════
        // [B] LOAD BAND — 50-segment LED matrix, midpoint tick, axis
        // ═════════════════════════════════════════════════════════════════
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 72

            ColumnLayout { anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; anchors.topMargin: 8; anchors.bottomMargin: 6; spacing: 5
                RowLayout { Layout.fillWidth: true
                    Eyebrow { text: "CPU LOAD / %" }
                    Item { Layout.fillWidth: true }
                    Text { text: root.m.cpuUsage.toFixed(1) + " %"
                        color: root.loadTier(root.m.cpuUsage)
                        font.family: Config.HudConfig.fontData; font.pixelSize: 10; font.bold: true }
                }
                HudLedBar {
                    Layout.fillWidth: true
                    height: 18
                    value: root.m.cpuUsage
                    litColor: root.loadTier(root.m.cpuUsage)
                    midpointIndex: 25
                }
                RowLayout { Layout.fillWidth: true
                    Micro { text: "0"; color: Config.HudConfig.textFaint; font.pixelSize: 8 }
                    Item { Layout.fillWidth: true }
                    Micro { text: "50"; color: Config.HudConfig.textFaint; font.pixelSize: 8 }
                    Item { Layout.fillWidth: true }
                    Micro { text: "100"; color: Config.HudConfig.textFaint; font.pixelSize: 8 }
                }
            }
        }
        HDivider { }

        // ═════════════════════════════════════════════════════════════════
        // [C] HERO ROW — GPU cluster | MEM & CPU cluster
        // ═════════════════════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ── GPU cluster ──────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.minimumWidth: 0
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.topMargin: 8
                    spacing: 6
                    HudChip {
                        text: root.m.gpuName !== "" ? root.m.gpuName.toUpperCase() : "NO GPU DETECTED"
                    }
                    HudChip {
                        visible: root.m.gpuPcieGenMax > 0
                        text: "PCIE GEN" + root.m.gpuPcieGenMax + " ×" + root.m.gpuPcieWidth
                        accent: Config.HudConfig.cyan
                    }
                    Item { Layout.fillWidth: true }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 14; Layout.rightMargin: 14
                    spacing: 4
                    Text {
                        text: root.m.util > 0 ? Math.round(root.m.util) : "—"
                        color: Config.HudConfig.textHi
                        font.family: Config.HudConfig.fontData; font.pixelSize: 40; font.bold: true
                    }
                    Text {
                        text: "%"
                        color: Config.HudConfig.amber
                        font.family: Config.HudConfig.fontData; font.pixelSize: 15; font.bold: true
                        Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 7
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.m.clockMHz > 0 ? Math.round(root.m.clockMHz) + " MHZ" : "— MHZ"
                        color: Config.HudConfig.textDim
                        font.family: Config.HudConfig.fontData; font.pixelSize: 10; font.bold: true
                        Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 7
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Layout.leftMargin: 10; Layout.rightMargin: 10
                    spacing: 10

                    Item {
                        Layout.fillHeight: true
                        Layout.preferredWidth: Math.min(250, height * 1.6)
                        CoreDashDial {
                            anchors.fill: parent
                            anchors.bottomMargin: 10
                            value: root.m.util
                        }
                        Text {
                            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                            text: "TACH"
                            color: Config.HudConfig.textFaint
                            font.family: Config.HudConfig.fontUi; font.pixelSize: 7; font.bold: true; font.letterSpacing: 1.4
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        Layout.minimumWidth: 0
                        spacing: 3
                        RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            StatCell { Layout.fillWidth: true; label: "BUS"
                                value: root.m.gpuPcieGenMax > 0 ? "PCIE GEN" + root.m.gpuPcieGenMax : "—" }
                            StatCell { Layout.fillWidth: true; label: "RATE"
                                value: root.m.gpuPcieGenMax > 0 ? Config.HudConfig.gtRate(root.m.gpuPcieGenMax) + " GT/S" : "—"
                                accent: Config.HudConfig.cyan }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            StatCell { Layout.fillWidth: true; label: "TGP"
                                value: root.m.powerW > 0 ? root.m.powerW.toFixed(0) + " W" : "IDLE"
                                accent: root.m.powerW > 0 ? Config.HudConfig.amber : Config.HudConfig.textFaint }
                            StatCell { Layout.fillWidth: true; label: "LIMIT"
                                value: root.m.gpuPowerLimitW > 0 ? root.m.gpuPowerLimitW.toFixed(0) + " W" : "—" }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            StatCell { Layout.fillWidth: true; label: "CORE TEMP"
                                value: root.m.temp > 0 ? root.m.temp.toFixed(0) + "°C" : "—"
                                accent: root.m.temp > 0 ? root.tempTier(root.m.temp) : Config.HudConfig.textFaint }
                            StatCell { Layout.fillWidth: true; label: "FAN"
                                value: root.m.fanPct > 0 ? root.m.fanPct.toFixed(0) + "%" : "STOP 0DB"
                                accent: root.m.fanPct > 0 ? Config.HudConfig.textBody : Config.HudConfig.textFaint }
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 14; Layout.rightMargin: 14
                    spacing: 3
                    SubEngine { label: "SM · CUDA";  value: root.m.gpuSmPct }
                    SubEngine { label: "ENC · AV1";  value: root.m.gpuEncPct }
                    SubEngine { label: "DEC · NVDEC"; value: root.m.gpuDecPct }
                    SubEngine { label: "OFA · FLOW"; value: root.m.gpuOfaPct }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.bottomMargin: 8
                    spacing: 3
                    RowLayout {
                        Layout.fillWidth: true
                        Eyebrow { text: "VRAM" }
                        Item { Layout.fillWidth: true }
                        Micro { text: root.m.vramUsedGB.toFixed(1) + " / " + root.m.vramTotalGB.toFixed(0) + " GB"
                            color: Config.HudConfig.textBody; font.bold: true }
                    }
                    HudMeterBar {
                        Layout.fillWidth: true
                        value: root.m.vramPct
                        fill: Config.HudConfig.amber
                    }
                }
            }

            VDivider { }

            // ── MEM & CPU cluster ─────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.minimumWidth: 0
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.topMargin: 8
                    spacing: 6
                    HudChip { text: root.m.cpuModel !== "" ? root.m.cpuModel.toUpperCase() : "CPU" }
                    HudChip {
                        text: "RAM " + Math.round(root.m.ramTotalGB) + "G"
                        accent: Config.HudConfig.cyan
                    }
                    Item { Layout.fillWidth: true }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 14; Layout.rightMargin: 14
                    spacing: 12
                    ColumnLayout {
                        spacing: 0
                        RowLayout {
                            spacing: 4
                            Text {
                                text: Math.round(root.m.ramPct)
                                color: Config.HudConfig.textHi
                                font.family: Config.HudConfig.fontData; font.pixelSize: 40; font.bold: true
                            }
                            Text {
                                text: "%"
                                color: Config.HudConfig.cyan
                                font.family: Config.HudConfig.fontData; font.pixelSize: 15; font.bold: true
                                Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 7
                            }
                        }
                        Micro { text: root.m.ramUsedGB.toFixed(1) + " / " + root.m.ramTotalGB.toFixed(1) + " GiB · SYSTEM MEMORY" }
                    }
                    Item { Layout.fillWidth: true }
                    ColumnLayout {
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 2
                        spacing: 2
                        Text { text: "MAX BOOST " + root.m.cpuMaxGhz.toFixed(2) + " GHZ"
                            color: Config.HudConfig.textDim
                            font.family: Config.HudConfig.fontData; font.pixelSize: 9; font.bold: true }
                        Text { text: "THREADS " + root.m.cpuThreads
                            color: Config.HudConfig.textDim
                            font.family: Config.HudConfig.fontData; font.pixelSize: 9; font.bold: true }
                        Text { text: "GOVERNOR " + (root.m.cpuGovernor !== "" ? root.m.cpuGovernor.toUpperCase() : "—")
                            color: Config.HudConfig.textDim
                            font.family: Config.HudConfig.fontData; font.pixelSize: 9; font.bold: true }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Layout.leftMargin: 14; Layout.rightMargin: 14
                    radius: Config.HudConfig.radiusSm
                    color: Config.HudConfig.wellDeep
                    border.color: Config.HudConfig.borderHi; border.width: 1
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 5
                        Eyebrow { text: "MEMORY POOLS"; Layout.leftMargin: 2 }
                        PoolRow { label: "ACTIVE ANON"; giB: root.m.memActiveAnonGiB }
                        PoolRow { label: "PAGE CACHE"; giB: root.m.memPageCacheGiB }
                        PoolRow { label: "SLAB"; giB: root.m.memSlabGiB }
                        PoolRow {
                            visible: root.m.zramUsedGB > 0.05
                            label: "ZRAM"; giB: root.m.zramUsedGB
                            note: root.m.zramRatio > 0 ? root.m.zramUsedGB.toFixed(1) + " G · " + root.m.zramRatio.toFixed(1) + ":1" : ""
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 14; Layout.rightMargin: 14
                    Layout.preferredHeight: 40
                    radius: Config.HudConfig.radiusSm
                    color: Config.HudConfig.wellDeep
                    border.color: Config.HudConfig.borderHi; border.width: 1
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        spacing: 12
                        ColumnLayout {
                            spacing: 0
                            Text { text: "EFFECTIVE"
                                color: Config.HudConfig.textFaint
                                font.family: Config.HudConfig.fontUi; font.pixelSize: 7; font.bold: true; font.letterSpacing: 1.2 }
                            Text { text: root.m.cpuGhz.toFixed(2) + " GHZ"
                                color: Config.HudConfig.cyan
                                font.family: Config.HudConfig.fontData; font.pixelSize: 13; font.bold: true }
                        }
                        Item { Layout.fillWidth: true }
                        ColumnLayout {
                            spacing: 0
                            Text { text: "UPTIME"
                                color: Config.HudConfig.textFaint
                                font.family: Config.HudConfig.fontUi; font.pixelSize: 7; font.bold: true; font.letterSpacing: 1.2 }
                            Text { text: root.m.uptime.toUpperCase()
                                color: Config.HudConfig.textBody
                                font.family: Config.HudConfig.fontData; font.pixelSize: 11; font.bold: true }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.bottomMargin: 8
                    spacing: 8
                    Eyebrow { text: "SWAP" }
                    HudMeterBar {
                        Layout.fillWidth: true
                        value: root.m.swapPct
                        fill: root.m.swapPct > 50 ? Config.HudConfig.amber : Config.HudConfig.cyan
                    }
                    Micro { text: root.m.swapUsedGB.toFixed(1) + "/" + root.m.swapTotalGB.toFixed(0) + " GB"
                        color: Config.HudConfig.textBody; font.bold: true }
                }
            }
        }
        HDivider { }

        // ═════════════════════════════════════════════════════════════════
        // [D] LCD BAND — embedded Mystique controller (shared component;
        //     state lives in LcdConfigService so this and the standalone
        //     MYSTIQUE AIO pane always agree)
        // ═════════════════════════════════════════════════════════════════
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 368   // the panel's internal minimum (~385
                                          // unshrunk — see the 176px device below)
            LcdControllerPanel {
                anchors.fill: parent
                embedded: true
            }
        }
        HDivider { }

        // ═════════════════════════════════════════════════════════════════
        // [E] PRECISION QUARTERS — CPU TEMP · PER-CORE · STORAGE · ENGINE
        // ═════════════════════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ── CPU TEMP: 14-seg 0–110°C scale, 90° marker ───────────────
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.minimumWidth: 0
                spacing: 3
                Eyebrow { Layout.leftMargin: 14; Layout.topMargin: 8; text: "CPU TEMP" }
                RowLayout {
                    Layout.leftMargin: 14; spacing: 3
                    Text {
                        text: root.m.cpuTemp > 0 ? root.m.cpuTemp.toFixed(0) : "—"
                        color: root.m.cpuTemp > 0 ? Config.HudConfig.textHi : Config.HudConfig.textFaint
                        font.family: Config.HudConfig.fontData; font.pixelSize: 22; font.bold: true
                    }
                    Text {
                        text: "°C"
                        color: root.tempTier(root.m.cpuTemp)
                        font.family: Config.HudConfig.fontData; font.pixelSize: 11; font.bold: true
                        Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 4
                    }
                }
                Item { Layout.fillWidth: true; Layout.fillHeight: true
                    ColumnLayout {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.leftMargin: 14; anchors.rightMargin: 14
                        spacing: 3
                        HudLedBar {
                            Layout.fillWidth: true; height: 12
                            segments: 14
                            value: Math.min(110, root.m.cpuTemp) / 110 * 100
                            litColor: root.tempTier(root.m.cpuTemp)
                            midpointIndex: 11          // the 90° mark
                        }
                        RowLayout { Layout.fillWidth: true
                            Micro { text: "0"; color: Config.HudConfig.textFaint; font.pixelSize: 7 }
                            Item { Layout.fillWidth: true }
                            Micro { text: "90"; color: Config.HudConfig.red; font.pixelSize: 7 }
                            Item { Layout.fillWidth: true }
                            Micro { text: "110"; color: Config.HudConfig.textFaint; font.pixelSize: 7 }
                        }
                    }
                }
                Item { Layout.fillWidth: true; Layout.preferredHeight: 8 }
            }
            VDivider { }

            // ── PER-CORE: 2×8 LED array ──────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.minimumWidth: 0
                spacing: 3
                Eyebrow { Layout.leftMargin: 14; Layout.topMargin: 8; text: "PER-CORE LOAD" }
                Micro { Layout.leftMargin: 14; text: root.coreCount + " THREADS"
                    color: Config.HudConfig.textFaint; font.pixelSize: 7 }
                Item { Layout.fillWidth: true; Layout.fillHeight: true
                    Grid {
                        anchors.centerIn: parent
                        columns: 8
                        columnSpacing: 3; rowSpacing: 3
                        Repeater {
                            model: 16
                            Rectangle {
                                width: 11; height: 11; radius: 2
                                readonly property real _load: root.m.perCoreLoad.length > index
                                                              ? root.m.perCoreLoad[index] : 0
                                color: _load > 1 ? root.loadTier(_load) : Config.HudConfig.ledDim
                            }
                        }
                    }
                }
                Item { Layout.fillWidth: true; Layout.preferredHeight: 8 }
            }
            VDivider { }

            // ── STORAGE: per-filesystem rows ─────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.minimumWidth: 0
                spacing: 3
                Eyebrow { Layout.leftMargin: 14; Layout.topMargin: 8; text: "STORAGE" }
                Item { Layout.fillWidth: true; Layout.fillHeight: true
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14; anchors.rightMargin: 14
                        anchors.topMargin: 2; anchors.bottomMargin: 8
                        spacing: 5
                        Repeater {
                            model: root.m.disks.length > 3 ? root.m.disks.slice(0, 3) : root.m.disks
                            delegate: ColumnLayout {
                                id: dsk
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 2
                                RowLayout { Layout.fillWidth: true
                                    Text { text: root.driveLabel(dsk.modelData.mount)
                                        color: Config.HudConfig.textBody
                                        font.family: Config.HudConfig.fontData; font.pixelSize: 8; font.bold: true; font.letterSpacing: 0.8 }
                                    Item { Layout.fillWidth: true }
                                    Text { text: Math.round(dsk.modelData.pct) + "%"
                                        color: root.diskTier(dsk.modelData.pct)
                                        font.family: Config.HudConfig.fontData; font.pixelSize: 8; font.bold: true }
                                }
                                HudMeterBar {
                                    Layout.fillWidth: true; barHeight: 3
                                    value: dsk.modelData.pct
                                    fill: root.diskTier(dsk.modelData.pct)
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }
            VDivider { }

            // ── ENGINE: board sensors + dominant GPU process ─────────────
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.minimumWidth: 0
                spacing: 4
                Eyebrow { Layout.leftMargin: 14; Layout.topMargin: 8; text: "ENGINE" }
                Item { Layout.fillWidth: true; Layout.fillHeight: true
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14; anchors.rightMargin: 14
                        anchors.topMargin: 2; anchors.bottomMargin: 8
                        spacing: 4
                        Repeater {
                            model: root.engineRows
                            delegate: RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                Text { text: modelData.k
                                    color: Config.HudConfig.textDim
                                    font.family: Config.HudConfig.fontData; font.pixelSize: 8; font.bold: true; font.letterSpacing: 0.8 }
                                Item { Layout.fillWidth: true }
                                Text { text: modelData.v
                                    color: modelData.c
                                    font.family: Config.HudConfig.fontData; font.pixelSize: 10; font.bold: true }
                            }
                        }
                        Item { Layout.fillHeight: true }
                        Rectangle {
                            visible: root.m.processes.length > 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: 22
                            radius: 3
                            color: Config.HudConfig.well
                            border.color: Config.HudConfig.borderHi; border.width: 1
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8; anchors.rightMargin: 8
                                spacing: 6
                                Text { text: "01"
                                    color: Config.HudConfig.amber
                                    font.family: Config.HudConfig.fontData; font.pixelSize: 8; font.bold: true }
                                Text { text: root.m.processes.length > 0 ? root.m.processes[0].name : ""
                                    Layout.fillWidth: true; Layout.minimumWidth: 0
                                    color: Config.HudConfig.textBody
                                    font.family: Config.HudConfig.fontData; font.pixelSize: 8
                                    elide: Text.ElideRight }
                                Text { text: root.m.processes.length > 0 ? root.m.processes[0].memMiB.toFixed(0) + " MIB" : ""
                                    color: Config.HudConfig.cyan
                                    font.family: Config.HudConfig.fontData; font.pixelSize: 8; font.bold: true }
                            }
                        }
                        Text {
                            visible: root.m.processes.length === 0
                            text: "NO ACTIVE GPU PROCESSES"
                            color: Config.HudConfig.textFaint
                            font.family: Config.HudConfig.fontData; font.pixelSize: 8
                        }
                    }
                }
            }
        }
        HDivider { }

        // ═════════════════════════════════════════════════════════════════
        // [F] FOOTER RAIL — provenance · freshness
        // ═════════════════════════════════════════════════════════════════
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                text: "LOCAL TELEMETRY / 1S SAMPLE"
                color: Config.HudConfig.textFaint
                font.family: Config.HudConfig.fontData; font.pixelSize: 8; font.letterSpacing: 0.8 }
            Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                text: "UPDATED " + root._agoSec + "S AGO"
                color: root._agoSec > 5 ? Config.HudConfig.amber : Config.HudConfig.textFaint
                font.family: Config.HudConfig.fontData; font.pixelSize: 8; font.letterSpacing: 0.8 }
        }
    }
}
