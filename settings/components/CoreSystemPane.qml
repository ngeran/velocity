// =============================================================================
// CoreSystemPane.qml — SYSTEM: symmetric bento grid, graphs side by side
// =============================================================================
// Consolidated CPU + GPU + Memory + Drives in one symmetric layout:
//   Row 1 (25%): [CPU primary] [GPU info] [MEMORY success] — big numerals
//   Row 2 (15%): [DRIVE sq] [DRIVE sq] [GPU SPECS: clock/VRAM/fan/procs]
//   Row 3 (60%): [LOAD HISTORY] [GPU UTIL FLOW] [CORE HEAT MAP] — side by side
// Every section uses fillHeight — no dead zones, fully symmetric.
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

    // ── big-numeral stat block (fills its row height) ─────────────────────
    component StatBlock: Rectangle {
        property string label: ""
        property string value: "—"
        property string unit: ""
        property string sub: ""
        property color valueColor: Config.ThemeConfig.colors.text
        property real meterValue: -1
        property color meterColor: Config.ThemeConfig.colors.primary
        Layout.fillWidth: true; Layout.fillHeight: true
        radius: Config.ControlConfig.radiusPill
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
        border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
        ColumnLayout { anchors.fill: parent; anchors.margins: 12; spacing: 2
            Item { Layout.fillHeight: true }
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
                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 36; font.bold: true }
                Text { visible: unit !== ""; text: unit; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 14 }
                Item { Layout.fillWidth: true }
            }
            CoreBar { Layout.fillWidth: true; barHeight: 4; visible: meterValue >= 0
                value: meterValue; barColor: meterColor }
            Item { Layout.fillHeight: true }
        }
    }

    // ── compact drive square ──────────────────────────────────────────────
    component DriveSquare: Rectangle {
        property string name: ""
        property real pct: 0
        property string capacity: ""
        Layout.fillWidth: true; Layout.fillHeight: true
        radius: Config.ControlConfig.radiusPill
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
        border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
        ColumnLayout { anchors.fill: parent; anchors.margins: 10; spacing: 3
            RowLayout { Layout.fillWidth: true
                Text { text: name; color: Config.ThemeConfig.colors.text
                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 11; font.bold: true
                    elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: Math.round(pct) + "%"
                    color: root.diskTier(pct)
                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 16; font.bold: true }
            }
            CoreBar { Layout.fillWidth: true; barHeight: 3; value: pct; barColor: root.diskTier(pct) }
            Text { text: capacity; color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
        }
    }

    // ── chart card with header ────────────────────────────────────────────
    component ChartCard: Rectangle {
        default property alias chart: chartSlot.data
        property string title: ""
        Layout.fillWidth: true; Layout.fillHeight: true
        radius: Config.ControlConfig.radiusPill
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
        border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
        ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 4
            Text { text: title; color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                font.bold: true; font.letterSpacing: 1.0 }
            Item { id: chartSlot; Layout.fillWidth: true; Layout.fillHeight: true }
        }
    }

    // ═════════════════════════════════════════════════════════════════════
    // ROW 1 — HERO: CPU · GPU · MEMORY
    // ═════════════════════════════════════════════════════════════════════
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 1
        Layout.maximumHeight: 140
        spacing: Config.ControlConfig.space3

        StatBlock { label: "CPU"; sub: Services.CoreEngineService.cpuGhz.toFixed(2) + " GHz · " + Services.ThermalService.cpuTemp.toFixed(0) + "°C"
            value: Math.round(Services.CoreEngineService.cpuUsage); unit: "%"
            valueColor: Config.ThemeConfig.colors.primary
            meterValue: Services.CoreEngineService.cpuUsage
            meterColor: Config.ThemeConfig.colors.primary }
        StatBlock { label: "GPU"; sub: Services.GpuService.present ? Services.GpuService.powerW.toFixed(0) + " W · " + Services.GpuService.temp.toFixed(0) + "°C" : "OFFLINE"
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

    // ═════════════════════════════════════════════════════════════════════
    // ROW 2 — DRIVES + GPU SPECS + SENSORS
    // ═════════════════════════════════════════════════════════════════════
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 0.6
        Layout.maximumHeight: 100
        spacing: Config.ControlConfig.space2

        Repeater {
            model: Services.CoreEngineService.disks
            delegate: DriveSquare {
                name: root.driveLabel(modelData.mount)
                pct: modelData.pct
                capacity: modelData.usedGB.toFixed(0) + "G / " + modelData.totalGB.toFixed(0) + "G"
            }
        }

        // GPU SPECS tile — clock, VRAM, fan, processes, coolant, NVMe
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true
            radius: Config.ControlConfig.radiusPill
            color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
            border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
            ColumnLayout { anchors.fill: parent; anchors.margins: 10; spacing: 2
                RowLayout { Layout.fillWidth: true; spacing: 6
                    Text { text: "GPU SPECS"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8 }
                    Item { Layout.fillWidth: true }
                    Text { text: Services.GpuService.present ? Services.GpuService.name : ""
                        color: Config.ThemeConfig.colors.textDim; opacity: 0.7
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                        elide: Text.ElideRight }
                }
                RowLayout { Layout.fillWidth: true; spacing: 8
                    Text { text: "CLOCK"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true }
                    Text { text: Services.GpuService.clockMHz > 0 ? (Services.GpuService.clockMHz / 1000).toFixed(1) + "G" : "—"
                        color: Config.ThemeConfig.colors.info; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 12; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: "VRAM"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true }
                    Text { text: Services.GpuService.vramUsedGB.toFixed(1) + "/" + Services.GpuService.vramTotalGB.toFixed(0) + "G"
                        color: Config.ThemeConfig.colors.primary; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 12; font.bold: true }
                }
                RowLayout { Layout.fillWidth: true; spacing: 8
                    Text { text: "FAN"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true }
                    Text { text: Services.GpuService.fanPct.toFixed(0) + "%"
                        color: Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 12; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: "PROCS"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true }
                    Text { text: Services.GpuService.processes.length
                        color: Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 12; font.bold: true }
                }
            }
        }

        // SENSORS tile — coolant, NVMe, swap
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true
            radius: Config.ControlConfig.radiusPill
            color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
            border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
            ColumnLayout { anchors.fill: parent; anchors.margins: 10; spacing: 2
                RowLayout { Layout.fillWidth: true; spacing: 6
                    Text { text: "SENSORS"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8 }
                }
                RowLayout { Layout.fillWidth: true; spacing: 8
                    Text { text: "COOLANT"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true }
                    Text { text: Services.ThermalService.coolantAvailable ? Services.ThermalService.coolantTemp.toFixed(1) + "°C" : "—"
                        color: root.tempTier(Services.ThermalService.coolantTemp)
                        font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 12; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: "NVMe"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true }
                    Text { text: Services.ThermalService.nvmeTemp > 0 ? Services.ThermalService.nvmeTemp.toFixed(1) + "°C" : "—"
                        color: root.tempTier(Services.ThermalService.nvmeTemp)
                        font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 12; font.bold: true }
                }
                RowLayout { Layout.fillWidth: true; spacing: 8
                    Text { text: "SWAP"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true }
                    Text { text: Math.round(Services.CoreEngineService.swapPct) + "%"
                        color: Config.ThemeConfig.colors.textDim; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 12; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: "UPTIME"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true }
                    Text { text: Math.floor(Services.CoreEngineService.cpuGhz) > 0 ? "LIVE" : "—"
                        color: Config.ThemeConfig.colors.success; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 12; font.bold: true }
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════
    // ROW 3 — BODY: LOAD HISTORY | GPU UTIL FLOW (side by side, full width)
    // ═════════════════════════════════════════════════════════════════════
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 2.5
        spacing: Config.ControlConfig.space3

        // LOAD HISTORY — CPU (primary) + RAM (success) overlay
        ChartCard {
            title: "LOAD HISTORY"
            RowLayout { anchors.fill: parent; spacing: 4
                Rectangle { width: 5; height: 5; radius: 3; color: Config.ThemeConfig.colors.primary
                    Layout.alignment: Qt.AlignTop }
                Text { text: Math.round(Services.CoreEngineService.cpuUsage) + "%"
                    color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
                Rectangle { width: 5; height: 5; radius: 3; color: Config.ThemeConfig.colors.success
                    Layout.alignment: Qt.AlignTop }
                Text { text: Math.round(Services.CoreEngineService.ramPct) + "%"
                    color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
            }
            Item { anchors.fill: parent
                CoreSparkline { anchors.fill: parent
                    points: Services.CoreEngineService.cpuHistory
                    lineColor: Config.ThemeConfig.colors.primary }
                CoreSparkline { anchors.fill: parent
                    points: Services.CoreEngineService.memoryHistory
                    lineColor: Config.ThemeConfig.colors.success
                    fillEnabled: false; dashed: true; lineWidth: 1.2 }
            }
        }

        // GPU UTIL FLOW — info violet
        ChartCard {
            title: "GPU UTIL FLOW"
            RowLayout { anchors.fill: parent; spacing: 4
                Rectangle { width: 5; height: 5; radius: 3; color: Config.ThemeConfig.colors.info
                    Layout.alignment: Qt.AlignTop }
                Text { text: Math.round(Services.GpuService.util) + "%"
                    color: Config.ThemeConfig.colors.info; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
            }
            Item { anchors.fill: parent
                CoreSparkline { anchors.fill: parent
                    points: Services.GpuService.gpuHistory
                    lineColor: Config.ThemeConfig.colors.info }
            }
        }
    }
}
