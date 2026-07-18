// CoreOverviewPane.qml — compact at-a-glance overview for the CORE tab's
// Overview page: system status bar + a 3×2 grid of headline metric tiles
// (CPU/GPU temps, memory, storage, NVMe, coolant). No per-core matrix — the
// full breakdowns live on their dedicated pages (Processors / Environmental).

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

ColumnLayout {
    id: root
    spacing: 14

    CoreStatusHeader { Layout.fillWidth: true }

    GridLayout {
        Layout.fillWidth: true
        columns: 3; rowSpacing: 12; columnSpacing: 12

        // ── CPU PACKAGE ───────────────────────────────────────────────
        CoreCard {
            accent: Config.ThemeConfig.colors.primary; Layout.fillWidth: true
            ColumnLayout { Layout.fillWidth: true; spacing: 7
                Text { text: "CPU PACKAGE"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.0 }
                RowLayout { spacing: 2
                    Text { text: Math.round(Services.ThermalService.cpuTemp); color: Config.ThemeConfig.colors.primary; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 26; font.bold: true }
                    Text { text: "°C"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 12; Layout.alignment: Qt.AlignBottom }
                    Item { Layout.fillWidth: true }
                    Text { text: Services.ThermalService.cpuTemp > 80 ? "HOT" : "OK"; color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
                }
                CoreBar { Layout.fillWidth: true; barHeight: 4; value: Services.ThermalService.cpuTemp }
            }
        }

        // ── GPU CORE ──────────────────────────────────────────────────
        CoreCard {
            accent: Config.ThemeConfig.colors.secondary; Layout.fillWidth: true
            ColumnLayout { Layout.fillWidth: true; spacing: 7
                Text { text: "GPU CORE"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.0 }
                RowLayout { spacing: 2
                    Text { text: Math.round(Services.GpuService.temp); color: Config.ThemeConfig.colors.secondary; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 26; font.bold: true }
                    Text { text: "°C"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 12; Layout.alignment: Qt.AlignBottom }
                    Item { Layout.fillWidth: true }
                    Text { text: Math.round(Services.GpuService.powerW) + "W"; color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
                }
                CoreBar { Layout.fillWidth: true; barHeight: 4; value: Services.GpuService.temp; barColor: Config.ThemeConfig.colors.secondary }
            }
        }

        // ── MEMORY ────────────────────────────────────────────────────
        CoreCard {
            accent: Config.ThemeConfig.colors.warning; Layout.fillWidth: true
            ColumnLayout { Layout.fillWidth: true; spacing: 7
                Text { text: "MEMORY"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.0 }
                RowLayout { spacing: 2
                    Text { text: Services.CoreEngineService.ramUsedGB.toFixed(1); color: Config.ThemeConfig.colors.warning; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 26; font.bold: true }
                    Text { text: "/" + Services.CoreEngineService.ramTotalGB.toFixed(0) + "G"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; Layout.alignment: Qt.AlignBottom }
                    Item { Layout.fillWidth: true }
                    Text { text: Math.round(Services.CoreEngineService.ramPct) + "%"; color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
                }
                CoreBar { Layout.fillWidth: true; barHeight: 4; value: Services.CoreEngineService.ramPct; barColor: Config.ThemeConfig.colors.warning }
            }
        }

        // ── STORAGE ───────────────────────────────────────────────────
        CoreCard {
            accent: Config.ThemeConfig.colors.primary; Layout.fillWidth: true
            ColumnLayout { Layout.fillWidth: true; spacing: 7
                Text { text: "STORAGE"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.0 }
                RowLayout { spacing: 2
                    Text { text: Services.CoreEngineService.diskUsedTB.toFixed(2); color: Config.ThemeConfig.colors.primary; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 26; font.bold: true }
                    Text { text: "/" + Services.CoreEngineService.diskTotalTB.toFixed(1) + "T"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; Layout.alignment: Qt.AlignBottom }
                    Item { Layout.fillWidth: true }
                    Text { text: Services.CoreEngineService.diskPct + "%"; color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
                }
                CoreBar { Layout.fillWidth: true; barHeight: 4; value: Services.CoreEngineService.diskPct }
            }
        }

        // ── NVMe ──────────────────────────────────────────────────────
        CoreCard {
            accent: Config.ThemeConfig.colors.primary; Layout.fillWidth: true
            ColumnLayout { Layout.fillWidth: true; spacing: 7
                Text { text: "NVMe PRIMARY"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.0 }
                RowLayout { spacing: 2
                    Text { text: Services.ThermalService.nvmeTemp > 0 ? Services.ThermalService.nvmeTemp.toFixed(0) : "--"; color: Config.ThemeConfig.colors.primary; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 26; font.bold: true }
                    Text { text: "°C"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 12; Layout.alignment: Qt.AlignBottom }
                    Item { Layout.fillWidth: true }
                    Text { text: Services.ThermalService.nvmeTemp > 0 ? "GEN4" : "N/A"; color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
                }
                CoreBar { Layout.fillWidth: true; barHeight: 4; value: Services.ThermalService.nvmeTemp > 0 ? Services.ThermalService.nvmeTemp : 0 }
            }
        }

        // ── COOLANT ───────────────────────────────────────────────────
        CoreCard {
            accent: Config.ThemeConfig.colors.secondary; Layout.fillWidth: true
            ColumnLayout { Layout.fillWidth: true; spacing: 7
                Text { text: "LIQUID COOLANT"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.0 }
                RowLayout { spacing: 2
                    Text { text: Services.ThermalService.coolantAvailable ? Services.ThermalService.coolantTemp.toFixed(0) : "--"; color: Config.ThemeConfig.colors.secondary; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 26; font.bold: true }
                    Text { text: "°C"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 12; Layout.alignment: Qt.AlignBottom }
                    Item { Layout.fillWidth: true }
                    Text { text: Services.ThermalService.coolantAvailable ? "OK" : "N/A"; color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
                }
                CoreBar { Layout.fillWidth: true; barHeight: 4; value: Services.ThermalService.coolantAvailable ? Math.min(100, Services.ThermalService.coolantTemp) : 0; barColor: Config.ThemeConfig.colors.secondary }
            }
        }
    }
}
