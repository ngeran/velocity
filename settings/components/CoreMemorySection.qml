// CoreMemorySection.qml — system memory bank: capacity bar + available/swap.
// (Direct children of CoreCard's layout column.)

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

CoreCard {
    id: root
    accent: Config.ThemeConfig.colors.warning
    Layout.fillWidth: true

    // ── Header ──────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        ColumnLayout { spacing: 2
            Text { text: "SYSTEM MEMORY BANK"; color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.5 }
            Text { text: Services.CoreEngineService.ramTotalGB.toFixed(0) + " GB"; color: Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 18; font.bold: true }
        }
        Item { Layout.fillWidth: true }
        Rectangle { radius: 2; color: Config.ThemeConfig.colors.warning; opacity: 0.12
            Layout.preferredWidth: 76; Layout.preferredHeight: 20
            Text { anchors.centerIn: parent; text: Math.round(Services.CoreEngineService.ramPct) + "% USED"; color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
        }
    }

    // ── Capacity bar ────────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true; spacing: 6
        RowLayout { Layout.fillWidth: true
            Text { text: "CAPACITY UTILIZATION"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
            Item { Layout.fillWidth: true }
            Text { text: Services.CoreEngineService.ramUsedGB.toFixed(1) + " / " + Services.CoreEngineService.ramTotalGB.toFixed(0) + " GB"; color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
        }
        CoreBar { Layout.fillWidth: true; barHeight: 6; value: Services.CoreEngineService.ramPct; barColor: Config.ThemeConfig.colors.warning }
    }

    // ── Available + Swap tiles ──────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true; spacing: 10
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 64; radius: 3; color: "transparent"
            border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
            ColumnLayout { anchors.fill: parent; anchors.margins: 10; spacing: 2
                Text { text: "AVAILABLE"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                RowLayout { spacing: 2
                    Text { text: (Services.CoreEngineService.ramTotalGB - Services.CoreEngineService.ramUsedGB).toFixed(1); color: Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 20; font.bold: true }
                    Text { text: "GB"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 64; radius: 3; color: "transparent"
            border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
            ColumnLayout { anchors.fill: parent; anchors.margins: 10; spacing: 2
                Text { text: "SWAP"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                RowLayout { spacing: 2
                    Text { text: Services.CoreEngineService.swapUsedGB.toFixed(1); color: Config.ThemeConfig.colors.secondary; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 20; font.bold: true }
                    Text { text: "/ " + Services.CoreEngineService.swapTotalGB.toFixed(0) + " GB"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                }
            }
        }
    }
}
