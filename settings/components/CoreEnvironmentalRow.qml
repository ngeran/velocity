// CoreEnvironmentalRow.qml — 4 tiles: coolant, NVMe, disk capacity, swap.
// (Each CoreCard's items are direct children so the card sizes to content.)

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

RowLayout {
    spacing: 12

    // Coolant
    CoreCard {
        accent: Config.ThemeConfig.colors.secondary
        Layout.fillWidth: true
        RowLayout { Layout.fillWidth: true
            Text { text: "LIQUID COOLANT"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.0 }
            Item { Layout.fillWidth: true }
            Rectangle { width: 8; height: 8; radius: 4; color: Config.ThemeConfig.colors.secondary }
        }
        RowLayout { spacing: 2
            Text { text: Services.ThermalService.coolantAvailable ? Services.ThermalService.coolantTemp.toFixed(1) : "--"; color: Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 26; font.bold: true }
            Text { text: "°C"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 12 }
            Item { Layout.fillWidth: true }
        }
        CoreBar { Layout.fillWidth: true; value: Services.ThermalService.coolantAvailable ? Math.min(100, Services.ThermalService.coolantTemp) : 0 }
        Text { text: Services.ThermalService.coolantAvailable ? "OPTIMAL" : "NO SENSOR"; color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
    }

    // NVMe
    CoreCard {
        accent: Config.ThemeConfig.colors.primary
        Layout.fillWidth: true
        RowLayout { Layout.fillWidth: true
            Text { text: "NVMe PRIMARY"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.0 }
            Item { Layout.fillWidth: true }
            Rectangle { width: 8; height: 8; radius: 4; color: Config.ThemeConfig.colors.primary }
        }
        RowLayout { spacing: 2
            Text { text: Services.ThermalService.nvmeTemp > 0 ? Services.ThermalService.nvmeTemp.toFixed(1) : "--"; color: Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 26; font.bold: true }
            Text { text: "°C"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 12 }
            Item { Layout.fillWidth: true }
        }
        CoreBar { Layout.fillWidth: true; value: Services.ThermalService.nvmeTemp > 0 ? Math.min(100, Services.ThermalService.nvmeTemp) : 0; barColor: Config.ThemeConfig.colors.primary }
        Text { text: Services.ThermalService.nvmeTemp > 0 ? "GEN4 // ACTIVE" : "NOT FOUND"; color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
    }

    // Disk capacity
    CoreCard {
        accent: Config.ThemeConfig.colors.primary
        Layout.fillWidth: true
        RowLayout { Layout.fillWidth: true
            Text { text: "STORAGE POOL"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.0 }
            Item { Layout.fillWidth: true }
            Rectangle { width: 8; height: 8; radius: 4; color: Config.ThemeConfig.colors.primary }
        }
        RowLayout { spacing: 3
            Text { text: Services.CoreEngineService.diskUsedTB.toFixed(2); color: Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 26; font.bold: true }
            Text { text: "/ " + Services.CoreEngineService.diskTotalTB.toFixed(1) + " TB"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
            Item { Layout.fillWidth: true }
        }
        CoreBar { Layout.fillWidth: true; value: Services.CoreEngineService.diskPct; barColor: Config.ThemeConfig.colors.primary }
        Text { text: Services.CoreEngineService.diskPct + "% USED"; color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
    }

    // Swap
    CoreCard {
        accent: Config.ThemeConfig.colors.secondary
        Layout.fillWidth: true
        RowLayout { Layout.fillWidth: true
            Text { text: "VIRTUAL PAGING"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.0 }
            Item { Layout.fillWidth: true }
            Rectangle { width: 8; height: 8; radius: 4; color: Config.ThemeConfig.colors.secondary }
        }
        RowLayout { spacing: 2
            Text { text: Services.CoreEngineService.swapUsedGB.toFixed(1); color: Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 26; font.bold: true }
            Text { text: "/ " + Services.CoreEngineService.swapTotalGB.toFixed(0) + " GB"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
            Item { Layout.fillWidth: true }
        }
        CoreBar { Layout.fillWidth: true; value: Services.CoreEngineService.swapPct }
        Text { text: Services.CoreEngineService.swapPct > 0 ? "ACTIVE SWAP" : "IDLE"; color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
    }
}
