// =============================================================================
// CoreCpuSection.qml — CPU pane (Core tab, Processors; Shibumi viewport-fit)
// =============================================================================
// Fixed composition (§6.1 — no scrolling), sized for the compact pane (~504):
//   1. SPEC STRIP     — 4 accent-ticked tiles (cores / clock / temp / load)
//   2. LOAD HISTORY   — 2-min CPU + RAM overlay sparklines (shared 0-100 scale)
//   3. MAIN SPLIT     — global-load ring + metric tiles | per-core grid
//   4. STATUS FOOTER  — scheduler / turbo / threads chips + refresh cadence
// All values are live telemetry (CoreEngineService / ThermalService). Tier
// ramps (tempTier/loadTier) delegate to ThemeConfig.tierColor; every fill is a
// tint token (base01/base02 mapping per DESIGN_TOKENS).
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

ColumnLayout {
    id: root
    spacing: Config.ControlConfig.space3

    readonly property int coreCount: Services.CoreEngineService.perCoreLoad.length

    // Tier ramps delegate to ThemeConfig.tierColor — thresholds stay here,
    // colour mapping is centralized so a theme swap retints every ramp.
    function tempTier(t) { return Config.ThemeConfig.tierColor(t, 55, 75) }
    function loadTier(v) { return Config.ThemeConfig.tierColor(v, 50, 85) }
    function schedLabel(v) { return v > 80 ? "HIGH" : (v > 40 ? "ACTIVE" : "OPTIMIZED") }

    // ── 1. SPEC STRIP ───────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true; spacing: Config.ControlConfig.space2

        component SpecTile: Rectangle {
            property string label: ""
            property string value: "—"
            property color tick: Config.ThemeConfig.colors.primary
            property color valueColor: Config.ThemeConfig.colors.text
            Layout.fillWidth: true; Layout.preferredHeight: 46
            radius: Config.ControlConfig.radiusPill
            color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
            border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
            Rectangle { anchors.left: parent.left; anchors.leftMargin: 6
                anchors.top: parent.top; anchors.topMargin: 8
                anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                width: 3; radius: 1.5; color: parent.tick }
            ColumnLayout { anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 8
                anchors.topMargin: 7; anchors.bottomMargin: 7; spacing: 0
                Text { text: label; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                Text { text: value; color: valueColor
                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 15; font.bold: true }
            }
        }

        SpecTile { label: "Cores";  value: root.coreCount + "-CORE"
            tick: Config.ThemeConfig.colors.primary; valueColor: Config.ThemeConfig.colors.text }
        SpecTile { label: "Clock";  value: Services.CoreEngineService.cpuGhz.toFixed(2) + " GHz"
            tick: Config.ControlConfig.accent; valueColor: Config.ThemeConfig.colors.text }
        SpecTile { label: "Package"; value: Math.round(Services.ThermalService.cpuTemp) + " °C"
            tick: root.tempTier(Services.ThermalService.cpuTemp); valueColor: root.tempTier(Services.ThermalService.cpuTemp) }
        SpecTile { label: "Avg Load"; value: Math.round(Services.CoreEngineService.cpuUsage) + " %"
            tick: root.loadTier(Services.CoreEngineService.cpuUsage); valueColor: root.loadTier(Services.CoreEngineService.cpuUsage) }
    }

    // ── 1b. LOAD HISTORY — 2-min CPU + RAM overlay ──────────────────────
    // CPU = solid accent line + soft fill; RAM = dashed primary line, no fill,
    // one shared pinned 0-100 scale. History is owned by CoreEngineService
    // (singleton) so it survives panel close/reopen.
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 80
        radius: Config.ControlConfig.radiusPill
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
        border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 8; spacing: 4

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text { text: "LOAD HISTORY"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                Item { Layout.fillWidth: true }
                RowLayout { spacing: 4
                    Rectangle { width: 6; height: 6; radius: 3; color: Config.ThemeConfig.colors.accent }
                    Text { text: "CPU"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                }
                RowLayout { spacing: 4
                    Rectangle { width: 6; height: 6; radius: 3; color: Config.ThemeConfig.colors.primary }
                    Text { text: "RAM"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                }
                Text { text: "2 MIN"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.letterSpacing: 0.8 }
            }

            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                CoreSparkline {
                    anchors.fill: parent
                    points: Services.CoreEngineService.cpuHistory
                    lineColor: Config.ThemeConfig.colors.accent
                    fixedMaximum: 100
                }
                CoreSparkline {
                    anchors.fill: parent
                    points: Services.CoreEngineService.memoryHistory
                    lineColor: Config.ThemeConfig.colors.primary
                    fillEnabled: false; dashed: true; lineWidth: 1.2
                    fixedMaximum: 100
                }
            }
        }
    }

    // ── 2. MAIN SPLIT: ring+metrics (left) | per-core grid (right) ───────
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Config.ControlConfig.space3

        // LEFT — global utilization ring + 2×2 metric tiles
        CoreCard {
            accent: Config.ThemeConfig.colors.primary
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: Config.ControlConfig.space2

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "GLOBAL LOAD"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                    Item { Layout.fillWidth: true }
                    Rectangle { width: 7; height: 7; radius: 4; color: Config.ThemeConfig.colors.success
                        SequentialAnimation on opacity { loops: Animation.Infinite; running: Config.SharedState.dashboardVisible
                            NumberAnimation { to: 0.3; duration: 700 } NumberAnimation { to: 1; duration: 700 } } }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    HudGauge {
                        value: Services.CoreEngineService.cpuUsage; max: 100; size: 118
                        accent: root.loadTier(Services.CoreEngineService.cpuUsage)
                        label: "UTILIZATION"; unit: "%"
                    }
                    Item { Layout.fillWidth: true }
                }

                component MetricTile: Rectangle {
                    property string label: ""
                    property string value: "—"
                    property string unit: ""
                    property color valueColor: Config.ThemeConfig.colors.text
                    property real meterValue: 0
                    property color meterColor: Config.ControlConfig.accent
                    Layout.fillWidth: true; Layout.preferredHeight: 56
                    radius: Config.ControlConfig.radiusPill
                    color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
                    border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
                    ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 3
                        Text { text: label; color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8 }
                        RowLayout { spacing: 2
                            Text { text: value; color: valueColor
                                font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 16; font.bold: true }
                            Text { visible: unit !== ""; text: unit; color: Config.ThemeConfig.colors.textDim
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
                            Item { Layout.fillWidth: true }
                        }
                        CoreBar { Layout.fillWidth: true; barHeight: 3
                            value: meterValue; barColor: meterColor; visible: meterValue > 0 || label === "PEAK TEMP" }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true; columns: 2; rowSpacing: Config.ControlConfig.space2; columnSpacing: Config.ControlConfig.space2

                    MetricTile { label: "PEAK TEMP"; value: Services.ThermalService.cpuTemp.toFixed(1); unit: "°C"
                        valueColor: root.tempTier(Services.ThermalService.cpuTemp)
                        // Package temp only spans a useful band (omarchy trick):
                        // anchoring at 30-100°C keeps a cold chip from looking
                        // half-loaded.
                        meterValue: Math.max(0, Math.min(100, (Services.ThermalService.cpuTemp - 30) * 100 / 70))
                        meterColor: root.tempTier(Services.ThermalService.cpuTemp) }
                    MetricTile { label: "UTILIZATION"; value: Math.round(Services.CoreEngineService.cpuUsage); unit: "%"
                        valueColor: root.loadTier(Services.CoreEngineService.cpuUsage)
                        meterValue: Services.CoreEngineService.cpuUsage
                        meterColor: root.loadTier(Services.CoreEngineService.cpuUsage) }
                    MetricTile { label: "CLOCK"; value: Services.CoreEngineService.cpuGhz.toFixed(2); unit: "GHz"
                        valueColor: Config.ControlConfig.accent }
                    MetricTile { label: "THREADS"; value: root.coreCount; unit: "thr"
                        valueColor: Config.ThemeConfig.colors.primary }
                }
            }
        }

        // RIGHT — per-core array
        CoreCard {
            accent: Config.ThemeConfig.colors.secondary
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: Config.ControlConfig.space2

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "PER-CORE ARRAY"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                    Item { Layout.fillWidth: true }
                    Rectangle { radius: Config.ControlConfig.radiusSmall
                        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.12)
                        border.color: Config.ThemeConfig.colors.secondary; border.width: 1
                        height: 18; width: arrNodes.implicitWidth + 12
                        Text { id: arrNodes; anchors.centerIn: parent; text: root.coreCount + " CORES"
                            color: Config.ThemeConfig.colors.secondary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true } }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: root.coreCount >= 24 ? 6 : (root.coreCount >= 12 ? 4 : 3)
                    rowSpacing: 6; columnSpacing: 6
                    Repeater {
                        model: Services.CoreEngineService.perCoreLoad
                        delegate: Rectangle {
                            id: coreTile
                            property real load: modelData
                            Layout.fillWidth: true; Layout.preferredHeight: 44
                            radius: Config.ControlConfig.radiusSmall
                            color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
                            border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
                            ColumnLayout { anchors.fill: parent; anchors.margins: 6; spacing: 4
                                RowLayout { Layout.fillWidth: true
                                    Text { text: "C" + (index + 1).toString().padStart(2, "0"); color: Config.ThemeConfig.colors.textDim
                                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                                    Item { Layout.fillWidth: true }
                                    Text { text: Math.round(coreTile.load) + "%"; color: root.loadTier(coreTile.load)
                                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                                }
                                CoreBar { Layout.fillWidth: true; barHeight: 3; value: coreTile.load; barColor: root.loadTier(coreTile.load) }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── 3. STATUS FOOTER ────────────────────────────────────────────────
    component StatusChip: Rectangle {
        property color tick: Config.ControlConfig.accent
        property string label: ""
        property string value: ""
        height: 22; width: chipRow.implicitWidth + 16
        radius: Config.ControlConfig.radiusPill
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.4)
        border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
        RowLayout { id: chipRow; anchors.centerIn: parent; spacing: 6
            Rectangle { width: 6; height: 6; radius: 3; color: tick }
            Text { text: label; color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8 }
            Text { text: value; color: tick
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
        }
    }

    RowLayout {
        Layout.fillWidth: true; spacing: Config.ControlConfig.space2

        StatusChip { label: "SCHEDULER"; value: root.schedLabel(Services.CoreEngineService.cpuUsage)
            tick: root.loadTier(Services.CoreEngineService.cpuUsage) }
        StatusChip { label: "TURBO"; value: Services.CoreEngineService.cpuGhz > 0 ? "ACTIVE" : "IDLE"
            tick: Services.CoreEngineService.cpuGhz > 0 ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.textDim }
        StatusChip { label: "THREADS"; value: root.coreCount
            tick: Config.ControlConfig.accent }

        Item { Layout.fillWidth: true }
        Text { text: "REFRESH 1.0s"; color: Config.ThemeConfig.colors.textDim
            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.letterSpacing: 0.8 }
    }
}
