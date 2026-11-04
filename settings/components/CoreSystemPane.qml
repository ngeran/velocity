// =============================================================================
// CoreSystemPane.qml — SYSTEM: digital instrument cluster (HUD rebuild)
// =============================================================================
// The mock's tactical cluster: pure-black panel, 32px engineer's grid
// backdrop, amber/cyan telemetry (HudConfig tokens — fixed, theme-independent),
// hairline dividers between bands (not floating cards). Top to bottom:
//   [A] header rail   (removed 2026-11-03 — see the band note below)
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
    // (GPU CLK lived here until the CLOCK StatCell in the GPU grid took the
    // same reading — the quarter was one row short of fitting its pill.)
    readonly property var engineRows: [
        { k: "COOLANT", v: m.coolantAvailable ? m.coolantTemp.toFixed(0) + "°C" : "—",
          c: m.coolantAvailable ? tempTier(m.coolantTemp) : Config.HudConfig.textFaint },
        { k: "NVME", v: m.nvmeTemp > 0 ? m.nvmeTemp.toFixed(0) + "°C" : "—",
          c: m.nvmeTemp > 0 ? tempTier(m.nvmeTemp) : Config.HudConfig.textFaint }
    ]

    // ── [F] "UPDATED Ns AGO" — resets whenever live telemetry ticks ────────
    readonly property string _sig: m.cpuUsage.toFixed(3)
    property int _agoSec: 0
    on_SigChanged: _agoSec = 0
    // T4.3: dashboard-gated too (SystemInfoTab's shown&&visible idiom) — the
    // age counter kept ticking behind the hidden window.
    Timer { interval: 1000; repeat: true; running: Config.SharedState.dashboardVisible && root.visible; onTriggered: root._agoSec++ }

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

    // mini stat cell (label over value) for the dial-side engine grid.
    // Fixed width so a row of cells forms true columns — ragged,
    // content-sized cells made the BUS/RATE grid read as scatter.
    component StatCell: ColumnLayout {
        id: sc
        property string label: ""
        property string value: "—"
        property color accent: Config.HudConfig.textBody
        Layout.preferredWidth: 88
        spacing: 2
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
        // no maximumWidth: the bar runs to the row's right margin so the
        // %/IDLE column shares VRAM's right edge (the capped 200px bar left
        // the sub-engine block ending mid-card, misaligned with VRAM below)
        HudMeterBar { Layout.fillWidth: true
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
        // ([A] HEADER RAIL removed 2026-11-03 — "SYSTEM / TELEMETRY · LIVE"
        // duplicated the TELEMETRY tab's own chrome and its 28px went back to
        // the bands; freshness still reads in the [F] footer. The remaining
        // bands keep their letters.)
        // ═════════════════════════════════════════════════════════════════

        // ═════════════════════════════════════════════════════════════════
        // [B] LOAD BAND — 50-segment LED matrix, midpoint tick, axis.
        // Deliberately tall (128): the chunky segment strip is the card's
        // visual anchor, and the height comes out of the hero row ([C] is
        // fillHeight), which reads better dense.
        // ═════════════════════════════════════════════════════════════════
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 128

            ColumnLayout { anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; anchors.topMargin: 8; anchors.bottomMargin: 6; spacing: 6
                RowLayout { Layout.fillWidth: true
                    Eyebrow { text: "CPU LOAD / %" }
                    Item { Layout.fillWidth: true }
                    // Doto display numeral (Tokens minDisplayPx), mirroring
                    // the CPU TEMP quarter's number+unit voice
                    Text { text: root.m.cpuUsage.toFixed(1)
                        color: root.loadTier(root.m.cpuUsage)
                        font.family: Config.HudConfig.fontDoto; font.weight: Font.Black; font.pixelSize: 26 }
                    Text { text: "%"
                        color: root.loadTier(root.m.cpuUsage)
                        font.family: Config.HudConfig.fontData; font.pixelSize: 11; font.bold: true
                        Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 5 }
                }
                HudLedBar {
                    Layout.fillWidth: true
                    height: 56
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
        // [C] HERO ROW — GPU cluster | MEM & CPU cluster.
        // Pinned (not fillHeight): as a fillHeight sibling of the [E]
        // quarters it split the slack evenly and the quarters starved.
        // Fixed at the clusters' natural height; [E] takes the rest.
        // ═════════════════════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 296
            Layout.maximumHeight: 296   // hard clamp: the pane's distributor
                                        // still handed this row 333
            spacing: 0

            // ── GPU cluster ──────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.minimumWidth: 0
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.topMargin: 6
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
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.topMargin: 4
                    spacing: 12

                    // Dot-matrix ring gauge (Doto numeral core) — GPU util
                    // inside, core temp as the caption ring reads like the
                    // Doto reference: number in the dots' circle.
                    // Top-aligned so both halves' gauges start on the same
                    // line (the MEM rings sit at the top of their row too).
                    HudDotRing {
                        Layout.preferredWidth: 156
                        Layout.preferredHeight: 156
                        Layout.alignment: Qt.AlignTop
                        value: root.m.util
                        valueText: "" + Math.round(root.m.util)
                        caption: root.m.temp > 0 ? "GPU · " + root.m.temp.toFixed(0) + "°C" : "GPU"
                        accent: root.m.util >= 85 ? Config.HudConfig.red : Config.HudConfig.amber
                    }

                    // stat grid hugs the gauge (no fillWidth stretch) so the
                    // cells read as one instrument cluster with the ring.
                    // Fixed-width StatCells + shared row spacing keep the two
                    // columns vertically aligned; the graphics clock lives
                    // here as a 4th row instead of floating at the card edge.
                    ColumnLayout {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 2
                        spacing: 8
                        RowLayout {
                            spacing: 18
                            StatCell { label: "BUS"
                                value: root.m.gpuPcieGenMax > 0 ? "PCIE GEN" + root.m.gpuPcieGenMax : "—" }
                            StatCell { label: "RATE"
                                value: root.m.gpuPcieGenMax > 0 ? Config.HudConfig.gtRate(root.m.gpuPcieGenMax) + " GT/S" : "—"
                                accent: Config.HudConfig.cyan }
                        }
                        RowLayout {
                            spacing: 18
                            StatCell { label: "TGP"
                                value: root.m.powerW > 0 ? root.m.powerW.toFixed(0) + " W" : "IDLE"
                                accent: root.m.powerW > 0 ? Config.HudConfig.amber : Config.HudConfig.textFaint }
                            StatCell { label: "LIMIT"
                                value: root.m.gpuPowerLimitW > 0 ? root.m.gpuPowerLimitW.toFixed(0) + " W" : "—" }
                        }
                        RowLayout {
                            spacing: 18
                            StatCell { label: "CORE TEMP"
                                value: root.m.temp > 0 ? root.m.temp.toFixed(0) + "°C" : "—"
                                accent: root.m.temp > 0 ? root.tempTier(root.m.temp) : Config.HudConfig.textFaint }
                            StatCell { label: "FAN"
                                value: root.m.fanPct > 0 ? root.m.fanPct.toFixed(0) + "%" : "STOP 0DB"
                                accent: root.m.fanPct > 0 ? Config.HudConfig.textBody : Config.HudConfig.textFaint }
                        }
                        RowLayout {
                            spacing: 18
                            StatCell { label: "CLOCK"
                                value: root.m.clockMHz > 0 ? Math.round(root.m.clockMHz) + " MHZ" : "—"
                                accent: Config.HudConfig.textDim }
                        }
                    }
                    Item { Layout.fillWidth: true }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 14; Layout.rightMargin: 14
                    spacing: 2
                    SubEngine { label: "SM · CUDA";  value: root.m.gpuSmPct }
                    SubEngine { label: "ENC · AV1";  value: root.m.gpuEncPct }
                    SubEngine { label: "DEC · NVDEC"; value: root.m.gpuDecPct }
                    SubEngine { label: "OFA · FLOW"; value: root.m.gpuOfaPct }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.bottomMargin: 6
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
                    Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.topMargin: 6
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
                    Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.topMargin: 4
                    spacing: 10

                    // Dot-matrix ring pair (Doto), mirroring the reference
                    // cluster: CPU load ring + MEM pressure ring, the CPU/MEM
                    // rail stacked to their right.
                    HudDotRing {
                        Layout.preferredWidth: 112
                        Layout.preferredHeight: 112
                        value: root.m.cpuUsage
                        valueText: "" + Math.round(root.m.cpuUsage)
                        caption: root.m.cpuTemp > 0 ? "CPU · " + root.m.cpuTemp.toFixed(0) + "°C" : "CPU"
                        accent: root.loadTier(root.m.cpuUsage)
                    }
                    HudDotRing {
                        Layout.preferredWidth: 112
                        Layout.preferredHeight: 112
                        value: root.m.ramPct
                        valueText: "" + Math.round(root.m.ramPct)
                        caption: "MEM · " + root.m.ramUsedGB.toFixed(1) + "G"
                        accent: Config.HudConfig.cyan
                    }
                    // rail hugs the ring pair — one connected instrument row.
                    // Label column + value column (fixed label width) so the
                    // three values align vertically instead of run-on lines.
                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 10
                        spacing: 5
                        RowLayout {
                            spacing: 6
                            Text { text: "MAX BOOST"; Layout.preferredWidth: 54
                                color: Config.HudConfig.textFaint
                                font.family: Config.HudConfig.fontUi; font.pixelSize: 7; font.bold: true; font.letterSpacing: 1.2 }
                            Text { text: root.m.cpuMaxGhz.toFixed(2) + " GHZ"
                                color: Config.HudConfig.textDim
                                font.family: Config.HudConfig.fontData; font.pixelSize: 9; font.bold: true }
                        }
                        RowLayout {
                            spacing: 6
                            Text { text: "THREADS"; Layout.preferredWidth: 54
                                color: Config.HudConfig.textFaint
                                font.family: Config.HudConfig.fontUi; font.pixelSize: 7; font.bold: true; font.letterSpacing: 1.2 }
                            Text { text: "" + root.m.cpuThreads
                                color: Config.HudConfig.textDim
                                font.family: Config.HudConfig.fontData; font.pixelSize: 9; font.bold: true }
                        }
                        RowLayout {
                            spacing: 6
                            Text { text: "GOVERNOR"; Layout.preferredWidth: 54
                                color: Config.HudConfig.textFaint
                                font.family: Config.HudConfig.fontUi; font.pixelSize: 7; font.bold: true; font.letterSpacing: 1.2 }
                            Text { text: root.m.cpuGovernor !== "" ? root.m.cpuGovernor.toUpperCase() : "—"
                                color: Config.HudConfig.textDim
                                font.family: Config.HudConfig.fontData; font.pixelSize: 9; font.bold: true }
                        }
                    }
                    Item { Layout.fillWidth: true }
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
                    Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.bottomMargin: 6
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
            Layout.preferredHeight: 348   // sized to the panel's content minimum
                                          // (bigger values just starve [E])
            LcdControllerPanel {
                anchors.fill: parent
                embedded: true
            }
        }
        HDivider { }

        // ═════════════════════════════════════════════════════════════════
        // [E] PRECISION QUARTERS — CPU TEMP · PER-CORE · STORAGE · ENGINE
        // preferredHeight stated alongside fillHeight: the pane's
        // distributor otherwise assigns this row only its implicit height
        // while [C] absorbs the surplus.
        // ═════════════════════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 130
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
                        font.family: Config.HudConfig.fontDoto; font.weight: Font.Black; font.pixelSize: 26
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
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.bottomMargin: 6
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
                Item {
                    id: coreWell
                    Layout.fillWidth: true; Layout.fillHeight: true
                    // Per-thread dot columns — each thread is a column of
                    // small dots that lights from the bottom by its load
                    // (the CPU·60s reference texture: tiny round dots,
                    // activity height). Spacing stretches to fill the well;
                    // the dots themselves stay small.
                    Grid {
                        id: coreGrid
                        anchors.centerIn: parent
                        columns: 16
                        columnSpacing: Math.max(3, Math.min(14, (coreWell.width - 16 * 6) / 15))
                        rowSpacing: Math.max(2, (coreWell.height - 8 * 6) / 7)
                        Repeater {
                            model: 128
                            Rectangle {
                                readonly property int col: index % 16
                                readonly property int row: Math.floor(index / 16)
                                readonly property real _load: root.m.perCoreLoad.length > col
                                                              ? root.m.perCoreLoad[col] : 0
                                readonly property int lit: Math.round(_load / 100 * 8)
                                width: 6; height: 6; radius: 3
                                color: (7 - row) < lit && _load > 1
                                       ? root.loadTier(_load) : Config.HudConfig.ledDim
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
                Item { Layout.fillWidth: true; Layout.fillHeight: true; clip: true
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
                // Sensor rows pin to the top, process readout pins to the
                // bottom — anchored, not one flow: when the quarter runs
                // short of height (the LCD band's real minimum exceeds its
                // preferred and eats [E]'s slack) the clip cuts the ROWS,
                // never mid-way through the pill well.
                Item { Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    ColumnLayout {
                        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                        anchors.leftMargin: 14; anchors.rightMargin: 14; anchors.topMargin: 1
                        spacing: 3
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
                    }
                    Rectangle {
                        visible: root.m.processes.length > 0
                        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                        anchors.leftMargin: 14; anchors.rightMargin: 14; anchors.bottomMargin: 6
                        height: 22
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
                        anchors.bottom: parent.bottom; anchors.left: parent.left
                        anchors.leftMargin: 14; anchors.bottomMargin: 8
                        text: "NO ACTIVE GPU PROCESSES"
                        color: Config.HudConfig.textFaint
                        font.family: Config.HudConfig.fontData; font.pixelSize: 8
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
            Layout.preferredHeight: 20
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
