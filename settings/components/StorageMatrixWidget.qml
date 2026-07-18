// =============================================================================
// StorageMatrixWidget.qml — memory + NVMe + disk + activity (Dashboard tab)
// =============================================================================
// Tactical "Storage Matrix" card: RAM capacity bar, NVMe primary temp/health,
// data-pool utilisation, and a live CPU-activity sparkline ("I/O PULSE").
// Binds Services.CoreEngineService + Services.ThermalService. Item root with an
// internal ColumnLayout (anchors.fill) → drops into a DashboardCard. The I/O
// pulse uses real cpuUsage (the API exposes no per-disk I/O rate) — an honest
// stand-in for the reference's random traffic bars.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 9

        // ── header ──
        RowLayout {
            Layout.fillWidth: true
            WidgetHeader { icon: "󰆼"; label: "STORAGE MATRIX"; iconColor: Config.ThemeConfig.colors.success }
            Item { Layout.fillWidth: true }
            Rectangle {
                height: 14; width: enc.implicitWidth + 8
                color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.success, 0.10)
                border.color: Config.ThemeConfig.colors.success; border.width: 1
                Text { id: enc; anchors.centerIn: parent; text: "ENCRYPTED"
                    color: Config.ThemeConfig.colors.success; font.family: Config.ControlConfig.fontMono; font.pixelSize: 7; font.bold: true }
            }
        }

        // ── RAM ──
        ColumnLayout { Layout.fillWidth: true; spacing: 4
            RowLayout { Layout.fillWidth: true
                Text { text: "PHYSICAL MEMORY (DDR)"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.letterSpacing: 1 }
                Item { Layout.fillWidth: true }
                Text { text: Services.CoreEngineService.ramUsedGB.toFixed(1) + " / " + Services.CoreEngineService.ramTotalGB.toFixed(0) + " GB"
                    color: Config.ThemeConfig.colors.success; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
            }
            CoreBar { Layout.fillWidth: true; barHeight: 8; value: Services.CoreEngineService.ramPct; barColor: Config.ThemeConfig.colors.success }
        }

        // ── NVMe ──
        RowLayout { Layout.fillWidth: true; spacing: 8
            Text { text: "NVMe-0 PRIMARY"; color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.letterSpacing: 1 }
            Item { Layout.fillWidth: true }
            Text { text: (Services.ThermalService.nvmeTemp > 0 ? Services.ThermalService.nvmeTemp.toFixed(0) : "--") + "°C"
                color: Config.ThemeConfig.colors.success; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
            Rectangle { height: 12; width: nvmeH.implicitWidth + 8
                border.color: Config.ThemeConfig.colors.success; border.width: 1
                Text { id: nvmeH; anchors.centerIn: parent
                    text: Services.ThermalService.nvmeTemp > 0 ? "SECURE" : "N/A"
                    color: Config.ThemeConfig.colors.success; font.family: Config.ControlConfig.fontMono; font.pixelSize: 7; font.bold: true } }
        }

        // ── Data pool ──
        ColumnLayout { Layout.fillWidth: true; spacing: 4
            RowLayout { Layout.fillWidth: true
                Text { text: "DATA POOL"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.letterSpacing: 1 }
                Item { Layout.fillWidth: true }
                Text { text: Services.CoreEngineService.diskUsedTB.toFixed(2) + " / " + Services.CoreEngineService.diskTotalTB.toFixed(1) + " TB"
                    color: Config.ThemeConfig.colors.text; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
            }
            CoreBar { Layout.fillWidth: true; barHeight: 4; value: Services.CoreEngineService.diskPct; barColor: Config.ThemeConfig.colors.success }
        }

        // ── I/O pulse (live) ──
        ColumnLayout { Layout.fillWidth: true; Layout.fillHeight: true; spacing: 4
            RowLayout { Layout.fillWidth: true
                Text { text: "I/O PULSE"; color: Config.ThemeConfig.colors.success
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                Item { Layout.fillWidth: true }
                Text { text: "LIVE"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
            }
            HudSpark {
                Layout.fillWidth: true; Layout.fillHeight: true
                value: Services.CoreEngineService.cpuUsage; max: 100; accent: Config.ThemeConfig.colors.success
            }
        }
    }
}
