// =============================================================================
// CoreCpuSection.qml — CPU pane (Core tab; bold Shibumi: hero rings + heat map)
// =============================================================================
// Fixed composition (§6.1 — no scrolling):
//   1. HERO ROW      — three instrumentation rings (CPU / PACKAGE TEMP / RAM)
//                      with 30px numerals
//   2. BODY          — per-core HEAT MAP (btop-style intensity blocks, the
//                      visual centerpiece) | LOAD HISTORY + SPEC rows
//   3. STATUS FOOTER — scheduler / turbo / threads chips + refresh cadence
// All values are live telemetry (CoreEngineService / ThermalService). Tier
// ramps delegate to ThemeConfig.tierColor; fills are tint tokens.
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

    // Heat-map summary — peak core + average, derived per tick.
    readonly property var peakCore: {
        var arr = Services.CoreEngineService.perCoreLoad
        var pi = -1, pv = -1, sum = 0
        for (var i = 0; i < arr.length; i++) {
            if (arr[i] > pv) { pv = arr[i]; pi = i }
            sum += arr[i]
        }
        return { index: pi, value: pv, avg: arr.length > 0 ? sum / arr.length : 0 }
    }

    // ── 1. HERO ROW — three instrumentation rings ───────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Config.ControlConfig.space4

        Item { Layout.fillWidth: true }
        HudGauge {
            size: 116; valuePixelSize: 30; arcWidth: 7
            value: Services.CoreEngineService.cpuUsage; max: 100; unit: "%"
            accent: root.loadTier(Services.CoreEngineService.cpuUsage)
            label: "CPU"
        }
        Item { Layout.fillWidth: true }
        HudGauge {
            size: 116; valuePixelSize: 30; arcWidth: 7
            value: Services.ThermalService.cpuTemp; max: 100; unit: "°"
            accent: root.tempTier(Services.ThermalService.cpuTemp)
            label: "PACKAGE"
        }
        Item { Layout.fillWidth: true }
        HudGauge {
            size: 116; valuePixelSize: 30; arcWidth: 7
            value: Services.CoreEngineService.ramPct; max: 100; unit: "%"
            accent: Config.ThemeConfig.colors.warning
            label: "MEMORY"
        }
        Item { Layout.fillWidth: true }
    }

    // ── 2. BODY — heat map (left, centerpiece) | history + spec (right) ──
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Config.ControlConfig.space3

        // LEFT — per-core heat map
        CoreCard {
            accent: Config.ControlConfig.accent
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Config.ControlConfig.space2

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "CORE ACTIVITY"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                    Item { Layout.fillWidth: true }
                    // live summary — the heat map's legend/identifier
                    Text { text: root.peakCore.index >= 0
                            ? ("PEAK C" + (root.peakCore.index + 1) + " " + Math.round(root.peakCore.value)
                               + "%  ·  AVG " + Math.round(root.peakCore.avg) + "%")
                            : "—"
                        color: root.peakCore.value >= 50 ? root.loadTier(root.peakCore.value) : Config.ThemeConfig.colors.text
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 11; font.bold: true }
                }

                // btop-style intensity blocks: tier hue, load-proportional
                // saturation — light load = faint, busy core = saturated.
                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: root.coreCount >= 24 ? 8 : (root.coreCount >= 12 ? 8 : 6)
                    rowSpacing: 4; columnSpacing: 4
                    Repeater {
                        model: Services.CoreEngineService.perCoreLoad
                        delegate: Rectangle {
                            id: heatBlock
                            property real load: modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 4
                            color: Config.ThemeConfig.tint(root.loadTier(heatBlock.load),
                                                           Math.max(0.18, heatBlock.load / 100))
                            border.color: Config.ThemeConfig.colors.outlineVariant
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 400 } }
                        }
                    }
                }
            }
        }

        // RIGHT — load history + spec rows
        ColumnLayout {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            spacing: Config.ControlConfig.space3

            // 2-min CPU + RAM overlay — service-owned history survives reopen.
            CoreCard {
                accent: Config.ThemeConfig.colors.primary
                Layout.fillWidth: true
                Layout.fillHeight: true
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

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
                        Layout.fillWidth: true
                        Layout.fillHeight: true
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

            // SPEC — the numbers the rings don't show
            CoreCard {
                accent: Config.ThemeConfig.colors.secondary
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true; spacing: Config.ControlConfig.space2
                    Text { text: "SPEC"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                    InfoStatRow { label: "Clock"; value: Services.CoreEngineService.cpuGhz.toFixed(2) + " GHz"; accentValue: true }
                    InfoStatRow { label: "Threads"; value: root.coreCount }
                    InfoStatRow { label: "Scheduler"; value: root.schedLabel(Services.CoreEngineService.cpuUsage) }
                    InfoStatRow { label: "Turbo"; value: Services.CoreEngineService.cpuGhz > 0 ? "ACTIVE" : "IDLE" }
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
