// =============================================================================
// CoreSystemPane.qml — SYSTEM: CPU + GPU + Memory + Drives in one pane
// =============================================================================
// Consolidated view (user request): replaces the separate PROCESSORS, GPU,
// and MEMORY&ENV panes. Fixed composition (§6.1 — no scrolling):
//   1. HERO ROW       — CPU (primary) · GPU (info) · MEMORY (success)
//   2. SENSORS ROW    — PACKAGE TEMP · GPU TEMP · NVMe (small stat tiles)
//   3. DRIVES ROW     — every real filesystem as a square (diskTier colors)
//   4. BODY           — per-core heat map | load history + util flow strips
// Palette: primary=CPU, info=GPU, success=memory — no accent-orange.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

ColumnLayout {
    id: root
    spacing: Config.ControlConfig.space3

    readonly property int coreCount: Services.CoreEngineService.perCoreLoad.length

    function tempTier(t) { return Config.ThemeConfig.tierColor(t, 55, 75) }
    function loadTier(v) { return Config.ThemeConfig.tierColor(v, 50, 85) }
    function diskTier(p) { return Config.ThemeConfig.tierColor(p, 70, 85) }
    function driveLabel(mount) {
        return mount === "/" ? "SYSTEM" : (mount.split("/").pop() || mount)
    }

    readonly property var peakCore: {
        var arr = Services.CoreEngineService.perCoreLoad
        var pi = -1, pv = -1, sum = 0
        for (var i = 0; i < arr.length; i++) {
            if (arr[i] > pv) { pv = arr[i]; pi = i }
            sum += arr[i]
        }
        return { index: pi, value: pv, avg: arr.length > 0 ? sum / arr.length : 0 }
    }

    // ── shared: big-numeral stat block ────────────────────────────────────
    component StatBlock: Rectangle {
        property string label: ""
        property string value: "—"
        property string unit: ""
        property string sub: ""             // small secondary readout
        property color valueColor: Config.ThemeConfig.colors.text
        property real meterValue: -1        // <0 hides the meter
        property color meterColor: Config.ThemeConfig.colors.primary
        Layout.fillWidth: true; Layout.preferredHeight: 92
        radius: Config.ControlConfig.radiusPill
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
        border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
        ColumnLayout { anchors.fill: parent; anchors.margins: 12; spacing: 2
            RowLayout { Layout.fillWidth: true
                Text { text: label; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                    font.bold: true; font.letterSpacing: 1.0 }
                Item { Layout.fillWidth: true }
                Text { visible: sub !== ""; text: sub
                    color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
            }
            RowLayout { spacing: 4
                Text { text: value; color: valueColor
                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 34; font.bold: true }
                Text { visible: unit !== ""; text: unit; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 12 }
                Item { Layout.fillWidth: true }
            }
            CoreBar { Layout.fillWidth: true; barHeight: 4; visible: meterValue >= 0
                value: meterValue; barColor: meterColor }
        }
    }

    // ── shared: small sensor tile ─────────────────────────────────────────
    component SensorTile: Rectangle {
        property string label: ""
        property string value: "—"
        property string unit: ""
        property color valueColor: Config.ThemeConfig.colors.text
        property real meterValue: -1
        property color meterColor: Config.ThemeConfig.colors.warning
        Layout.fillWidth: true; Layout.preferredHeight: 52
        radius: Config.ControlConfig.radiusPill
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
        border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
        ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 2
            Text { text: label; color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                font.bold: true; font.letterSpacing: 0.8 }
            RowLayout { spacing: 2
                Text { text: value; color: valueColor
                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 18; font.bold: true }
                Text { visible: unit !== ""; text: unit; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
            }
        }
    }

    // ── 1. HERO — CPU / GPU / MEMORY ────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Config.ControlConfig.space3

        StatBlock { label: "CPU"; sub: Services.CoreEngineService.cpuGhz.toFixed(2) + " GHz"
            value: Math.round(Services.CoreEngineService.cpuUsage); unit: "%"
            valueColor: Config.ThemeConfig.colors.primary
            meterValue: Services.CoreEngineService.cpuUsage
            meterColor: Config.ThemeConfig.colors.primary }
        StatBlock { label: "GPU"; sub: Services.GpuService.present ? Services.GpuService.powerW.toFixed(0) + " W" : "OFFLINE"
            value: Math.round(Services.GpuService.util); unit: "%"
            valueColor: Config.ThemeConfig.colors.info
            meterValue: Services.GpuService.util
            meterColor: Config.ThemeConfig.colors.info }
        StatBlock { label: "MEMORY"; sub: (Services.CoreEngineService.ramTotalGB - Services.CoreEngineService.ramUsedGB).toFixed(0) + " GB FREE"
            value: Math.round(Services.CoreEngineService.ramPct); unit: "%"
            valueColor: Config.ThemeConfig.colors.success
            meterValue: Services.CoreEngineService.ramPct
            meterColor: Config.ThemeConfig.colors.success }
    }

    // ── 2. SENSORS — temps + VRAM ────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Config.ControlConfig.space2

        SensorTile { label: "PKG TEMP"
            value: Services.ThermalService.cpuTemp.toFixed(0); unit: "°C"
            valueColor: root.tempTier(Services.ThermalService.cpuTemp)
            meterValue: Math.max(0, Math.min(100, (Services.ThermalService.cpuTemp - 30) * 100 / 70))
            meterColor: root.tempTier(Services.ThermalService.cpuTemp) }
        SensorTile { label: "GPU TEMP"
            value: Services.GpuService.temp.toFixed(0); unit: "°C"
            valueColor: root.tempTier(Services.GpuService.temp)
            meterValue: Services.GpuService.temp
            meterColor: root.tempTier(Services.GpuService.temp) }
        SensorTile { label: "COOLANT"
            value: Services.ThermalService.coolantAvailable ? Services.ThermalService.coolantTemp.toFixed(1) : "--"; unit: "°C"
            valueColor: root.tempTier(Services.ThermalService.coolantTemp) }
        SensorTile { label: "NVMe"
            value: Services.ThermalService.nvmeTemp > 0 ? Services.ThermalService.nvmeTemp.toFixed(1) : "--"; unit: "°C"
            valueColor: root.tempTier(Services.ThermalService.nvmeTemp) }
        SensorTile { label: "VRAM"
            value: Math.round(Services.GpuService.vramPct); unit: "%"
            valueColor: Config.ThemeConfig.colors.primary }
    }

    // ── 3. DRIVES — square cards per filesystem ──────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Config.ControlConfig.space2

        Repeater {
            model: Services.CoreEngineService.disks
            delegate: Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 72
                radius: Config.ControlConfig.radiusPill
                color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
                border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
                ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 2
                    RowLayout { Layout.fillWidth: true
                        Text { text: root.driveLabel(modelData.mount)
                            color: Config.ThemeConfig.colors.text
                            font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 11; font.bold: true
                            elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: Math.round(modelData.pct) + "%"
                            color: root.diskTier(modelData.pct)
                            font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 14; font.bold: true }
                    }
                    CoreBar { Layout.fillWidth: true; barHeight: 3
                        value: modelData.pct; barColor: root.diskTier(modelData.pct) }
                    Text { text: modelData.usedGB.toFixed(0) + "G / " + modelData.totalGB.toFixed(0) + "G"
                        color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
                }
            }
        }
    }

    // ── 4. BODY — heat map | history strips ──────────────────────────────
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
                Layout.fillWidth: true; Layout.fillHeight: true
                spacing: Config.ControlConfig.space2

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "CORE ACTIVITY"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                    Item { Layout.fillWidth: true }
                    Text { text: root.peakCore.index >= 0
                            ? ("PEAK C" + (root.peakCore.index + 1) + " " + Math.round(root.peakCore.value)
                               + "%  ·  AVG " + Math.round(root.peakCore.avg) + "%")
                            : "—"
                        color: root.peakCore.value >= 50 ? root.loadTier(root.peakCore.value) : Config.ThemeConfig.colors.text
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 11; font.bold: true }
                }

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
                            Layout.fillWidth: true; Layout.fillHeight: true
                            radius: 4
                            color: Config.ThemeConfig.tint(root.loadTier(heatBlock.load),
                                                           Math.max(0.18, heatBlock.load / 100))
                            border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
                            Behavior on color { ColorAnimation { duration: 400 } }
                        }
                    }
                }
            }
        }

        // RIGHT — history strips
        ColumnLayout {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            spacing: Config.ControlConfig.space3

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                radius: Config.ControlConfig.radiusPill
                color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
                border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 8; spacing: 4
                    RowLayout { Layout.fillWidth: true; spacing: 8
                        Text { text: "LOAD HISTORY"; color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                        Item { Layout.fillWidth: true }
                        RowLayout { spacing: 4
                            Rectangle { width: 6; height: 6; radius: 3; color: Config.ThemeConfig.colors.primary }
                            Text { text: "CPU " + Math.round(Services.CoreEngineService.cpuUsage) + "%"
                                color: Config.ThemeConfig.colors.textDim
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true } }
                        RowLayout { spacing: 4
                            Rectangle { width: 6; height: 6; radius: 3; color: Config.ThemeConfig.colors.success }
                            Text { text: "RAM " + Math.round(Services.CoreEngineService.ramPct) + "%"
                                color: Config.ThemeConfig.colors.textDim
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true } }
                    }
                    Item { Layout.fillWidth: true; Layout.fillHeight: true
                        CoreSparkline { anchors.fill: parent
                            points: Services.CoreEngineService.cpuHistory
                            lineColor: Config.ThemeConfig.colors.primary }
                        CoreSparkline { anchors.fill: parent
                            points: Services.CoreEngineService.memoryHistory
                            lineColor: Config.ThemeConfig.colors.success
                            fillEnabled: false; dashed: true; lineWidth: 1.2 } }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                radius: Config.ControlConfig.radiusPill
                color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
                border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 8; spacing: 4
                    RowLayout { Layout.fillWidth: true; spacing: 8
                        Text { text: "GPU UTIL FLOW"; color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                        Item { Layout.fillWidth: true }
                        Text { text: Math.round(Services.GpuService.util) + "% NOW"
                            color: Config.ThemeConfig.colors.info
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true } }
                    Item { Layout.fillWidth: true; Layout.fillHeight: true
                        CoreSparkline { anchors.fill: parent
                            points: Services.GpuService.gpuHistory
                            lineColor: Config.ThemeConfig.colors.info } }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
