// =============================================================================
// CoreSystemPane.qml — SYSTEM: dense, space-efficient monitoring dashboard
// =============================================================================
// Reference-inspired: every pixel is used, numbers are prominent, no gaps.
//   Row 1 (fills):  [CPU block: util % + temp + clock + meter]
//                   [GPU block: util % + temp + VRAM + meter]
//                   [MEM block: % + used/free + swap + meter]
//   Row 2 (fills):  [SYSTEM drive + % + bar] [WD_BLACK drive + % + bar]
//                   [SYSTEM INFO: coolant/NVMe/fan/clock/procs]
//   Row 3 (fills):  [LOAD HISTORY graph] [GPU UTIL FLOW graph]
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

ColumnLayout {
    id: root
    spacing: 8

    readonly property int coreCount: Services.CoreEngineService.perCoreLoad.length

    function tempTier(t) { return Config.ThemeConfig.tierColor(t, 55, 75) }
    function loadTier(v) { return Config.ThemeConfig.tierColor(v, 50, 85) }
    function diskTier(p) { return Config.ThemeConfig.tierColor(p, 70, 85) }
    function driveLabel(mount) {
        return mount === "/" ? "SYSTEM" : (mount.split("/").pop() || mount)
    }

    // ═════════════════════════════════════════════════════════════════════
    // ROW 1 — HERO: CPU · GPU · MEMORY (dense blocks, no dead space)
    // ═════════════════════════════════════════════════════════════════════
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 2.2
        spacing: 8

        component MetricCard: Rectangle {
            property string title: ""
            property string bigValue: "—"
            property string bigUnit: ""
            property color bigColor: Config.ThemeConfig.colors.text
            property var rows: []           // [{label, value, color}]
            property real meterValue: -1
            property color meterColor: Config.ThemeConfig.colors.primary
            Layout.fillWidth: true; Layout.fillHeight: true
            radius: Config.ControlConfig.radiusPill
            color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
            border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 3

                // Title row
                Text { text: title; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                    font.bold: true; font.letterSpacing: 1.2 }

                // Big value + unit
                RowLayout { spacing: 3
                    Text { text: bigValue; color: bigColor
                        font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 42; font.bold: true }
                    Text { text: bigUnit; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 14 }
                    Item { Layout.fillWidth: true }
                }

                // Meter
                CoreBar { Layout.fillWidth: true; barHeight: 5; visible: meterValue >= 0
                    value: meterValue; barColor: meterColor }

                // Detail rows
                Repeater {
                    model: rows
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        required property var modelData
                        Text { text: modelData.label
                            color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
                        Item { Layout.fillWidth: true }
                        Text { text: modelData.value
                            color: modelData.color || Config.ThemeConfig.colors.text
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 11; font.bold: true }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        MetricCard {
            title: "CPU"
            bigValue: Math.round(Services.CoreEngineService.cpuUsage); bigUnit: "%"
            bigColor: Config.ThemeConfig.colors.primary
            meterValue: Services.CoreEngineService.cpuUsage
            meterColor: Config.ThemeConfig.colors.primary
            rows: [
                { label: "Clock", value: Services.CoreEngineService.cpuGhz.toFixed(2) + " GHz" },
                { label: "Temp", value: Services.ThermalService.cpuTemp.toFixed(0) + " °C",
                  color: root.tempTier(Services.ThermalService.cpuTemp) },
                { label: "Threads", value: root.coreCount }
            ]
        }

        MetricCard {
            title: "GPU"
            bigValue: Math.round(Services.GpuService.util); bigUnit: "%"
            bigColor: Config.ThemeConfig.colors.info
            meterValue: Services.GpuService.util
            meterColor: Config.ThemeConfig.colors.info
            rows: [
                { label: "VRAM", value: Services.GpuService.vramUsedGB.toFixed(1) + " / " + Services.GpuService.vramTotalGB.toFixed(0) + " GB",
                  color: Config.ThemeConfig.colors.primary },
                { label: "Temp", value: Services.GpuService.temp.toFixed(0) + " °C",
                  color: root.tempTier(Services.GpuService.temp) },
                { label: "Fan", value: Services.GpuService.fanPct.toFixed(0) + " %" }
            ]
        }

        MetricCard {
            title: "MEMORY"
            bigValue: Math.round(Services.CoreEngineService.ramPct); bigUnit: "%"
            bigColor: Config.ThemeConfig.colors.success
            meterValue: Services.CoreEngineService.ramPct
            meterColor: Config.ThemeConfig.colors.success
            rows: [
                { label: "Used", value: Services.CoreEngineService.ramUsedGB.toFixed(1) + " GB",
                  color: Config.ThemeConfig.colors.success },
                { label: "Free", value: (Services.CoreEngineService.ramTotalGB - Services.CoreEngineService.ramUsedGB).toFixed(1) + " GB" },
                { label: "Swap", value: Services.CoreEngineService.swapUsedGB.toFixed(1) + " GB" }
            ]
        }
    }

    // ═════════════════════════════════════════════════════════════════════
    // ROW 2 — DRIVES + SYSTEM INFO
    // ═════════════════════════════════════════════════════════════════════
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 1
        spacing: 8

        // Drive cards
        Repeater {
            model: Services.CoreEngineService.disks
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true; Layout.fillHeight: true
                radius: Config.ControlConfig.radiusPill
                color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
                border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
                clip: true
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 3
                    RowLayout { Layout.fillWidth: true
                        Text { text: root.driveLabel(modelData.mount)
                            color: Config.ThemeConfig.colors.text
                            font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 12; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Text { text: Math.round(modelData.pct) + "%"
                            color: root.diskTier(modelData.pct)
                            font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 20; font.bold: true }
                    }
                    CoreBar { Layout.fillWidth: true; barHeight: 4
                        value: modelData.pct; barColor: root.diskTier(modelData.pct) }
                    Text { text: modelData.usedGB.toFixed(0) + "G used · " + modelData.availGB.toFixed(0) + "G free · " + modelData.totalGB.toFixed(0) + "G total"
                        color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
                }
            }
        }

        // SYSTEM INFO — sensors + GPU extras in one dense card
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.preferredWidth: 1.5
            radius: Config.ControlConfig.radiusPill
            color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
            border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
            clip: true
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 10; spacing: 3

                Text { text: "SENSORS"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                    font.bold: true; font.letterSpacing: 1.2 }

                RowLayout { Layout.fillWidth: true
                    Text { text: "Coolant"
                        color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
                    Text { text: Services.ThermalService.coolantAvailable ? Services.ThermalService.coolantTemp.toFixed(1) + "°C" : "—"
                        color: root.tempTier(Services.ThermalService.coolantTemp); font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 13; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: "NVMe"
                        color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
                    Text { text: Services.ThermalService.nvmeTemp > 0 ? Services.ThermalService.nvmeTemp.toFixed(1) + "°C" : "—"
                        color: root.tempTier(Services.ThermalService.nvmeTemp); font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 13; font.bold: true }
                }

                RowLayout { Layout.fillWidth: true
                    Text { text: "Clock"
                        color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
                    Text { text: Services.GpuService.clockMHz > 0 ? (Services.GpuService.clockMHz / 1000).toFixed(2) + " GHz" : "—"
                        color: Config.ThemeConfig.colors.info; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 13; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: "Procs"
                        color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
                    Text { text: Services.GpuService.processes.length
                        color: Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 13; font.bold: true }
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════
    // ROW 3 — GRAPHS (fills remaining height, no cap)
    // ═════════════════════════════════════════════════════════════════════
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 1.5
        spacing: 8

        component ChartCard: Rectangle {
            property string title: ""
            default property alias chart: chartSlot.data
            Layout.fillWidth: true; Layout.fillHeight: true
            radius: Config.ControlConfig.radiusPill
            color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
            border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
            clip: true
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 8; spacing: 4
                RowLayout { Layout.fillWidth: true
                    Text { text: title; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                        font.bold: true; font.letterSpacing: 1.2 }
                }
                Item { id: chartSlot; Layout.fillWidth: true; Layout.fillHeight: true }
            }
        }

        ChartCard {
            title: "LOAD HISTORY"
            RowLayout { anchors.fill: parent; spacing: 4
                Rectangle { width: 4; height: 4; radius: 2; color: Config.ThemeConfig.colors.primary }
                Text { text: "CPU " + Math.round(Services.CoreEngineService.cpuUsage) + "%"
                    color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
                Rectangle { width: 4; height: 4; radius: 2; color: Config.ThemeConfig.colors.success }
                Text { text: "RAM " + Math.round(Services.CoreEngineService.ramPct) + "%"
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

        ChartCard {
            title: "GPU UTIL FLOW"
            RowLayout { anchors.fill: parent; spacing: 4
                Rectangle { width: 4; height: 4; radius: 2; color: Config.ThemeConfig.colors.info }
                Text { text: Math.round(Services.GpuService.util) + "%"
                    color: Config.ThemeConfig.colors.info; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
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
