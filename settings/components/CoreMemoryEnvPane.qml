// =============================================================================
// CoreMemoryEnvPane.qml — combined Memory Bank + Environmental (Core tab)
// =============================================================================
// Merges the former MEMORY BANKS and ENVIRONMENTAL pages into a single pane,
// rendered in the same tactical-HUD aesthetic as CoreOverviewPane: HudCard
// modules (sharp borders + corner brackets), monospace headers, black-40%
// metric tiles, display-font readouts and footer label/value rows. All colours
// are live ThemeConfig tokens; tempTier() shifts cool→warm→hot by value.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

RowLayout {
    id: root
    spacing: 14

    // cool → warm → hot severity colour, mapped to live theme tokens
    // (same helper CoreOverviewPane uses).
    function tempTier(t) {
        if (t >= 75) return Config.ThemeConfig.colors.error
        if (t >= 55) return Config.ThemeConfig.colors.warning
        return Config.ThemeConfig.colors.secondary
    }

    // ── 1. MEMORY BANK ──────────────────────────────────────────────────
    HudCard {
        accent: Config.ThemeConfig.colors.warning
        Layout.fillWidth: true
        Layout.fillHeight: true
        ColumnLayout {
            Layout.fillWidth: true; spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text { text: "MEMORY_BANK"; color: Config.ThemeConfig.colors.warning
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5 }
                Item { Layout.fillWidth: true }
                Rectangle { radius: 0; border.color: Config.ThemeConfig.colors.warning; border.width: 1
                    height: 14; width: memBadge.implicitWidth + 10
                    Text { id: memBadge; anchors.centerIn: parent; text: "ECC_ENCRYPTED"
                        color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 7; font.bold: true } }
            }

            // capacity readout + utilisation bar
            RowLayout {
                Layout.fillWidth: true
                Text { text: Services.CoreEngineService.ramTotalGB.toFixed(0) + " GB SYSTEM RAM"
                    color: Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 16; font.bold: true }
                Item { Layout.fillWidth: true }
                Text { text: Math.round(Services.CoreEngineService.ramPct) + "% USED"
                    color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
            }
            CoreBar { Layout.fillWidth: true; barHeight: 8; value: Services.CoreEngineService.ramPct; barColor: Config.ThemeConfig.colors.warning }

            // available + swap metric tiles
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Rectangle {
                    Layout.fillWidth: true; height: 58
                    color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
                    ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 3
                        Text { text: "AVAILABLE"; color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                        RowLayout { spacing: 3
                            Text { text: (Services.CoreEngineService.ramTotalGB - Services.CoreEngineService.ramUsedGB).toFixed(1)
                                color: Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 18; font.bold: true }
                            Text { text: "GB"; color: Config.ThemeConfig.colors.textDim
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; height: 58
                    color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
                    ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 3
                        Text { text: "SWAP"; color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                        RowLayout { spacing: 3
                            Text { text: Services.CoreEngineService.swapUsedGB.toFixed(1)
                                color: Config.ThemeConfig.colors.secondary; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 18; font.bold: true }
                            Text { text: "/ " + Services.CoreEngineService.swapTotalGB.toFixed(0) + " GB"
                                color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "USED"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                Text { text: Services.CoreEngineService.ramUsedGB.toFixed(1) + " GB"; color: Config.ThemeConfig.colors.warning
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
                Item { Layout.fillWidth: true }
                Text { text: "SWAP"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                Text { text: Math.round(Services.CoreEngineService.swapPct) + "%"; color: Config.ThemeConfig.colors.secondary
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
            }
        }
    }

    // ── 2. ENVIRONMENTAL ────────────────────────────────────────────────
    HudCard {
        accent: Config.ThemeConfig.colors.secondary
        Layout.fillWidth: true
        Layout.fillHeight: true
        ColumnLayout {
            Layout.fillWidth: true; spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text { text: "ENVIRONMENTAL"; color: Config.ThemeConfig.colors.secondary
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5 }
                Item { Layout.fillWidth: true }
                RowLayout { spacing: 5
                    Rectangle { width: 8; height: 8; radius: 4; color: Config.ThemeConfig.colors.success
                        SequentialAnimation on opacity { loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 700 } NumberAnimation { to: 1; duration: 700 } } }
                    Text { text: "SENSORS LIVE"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                }
            }

            // coolant + NVMe + storage metric tiles
            RowLayout {
                Layout.fillWidth: true; spacing: 8

                // liquid coolant
                Rectangle {
                    Layout.fillWidth: true; height: 80
                    color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
                    ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 4
                        Text { text: "LIQUID COOLANT"; color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                        RowLayout { spacing: 3
                            Text { text: Services.ThermalService.coolantAvailable ? Services.ThermalService.coolantTemp.toFixed(1) : "--"
                                color: root.tempTier(Services.ThermalService.coolantTemp)
                                font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 18; font.bold: true }
                            Text { text: "°C"; color: Config.ThemeConfig.colors.textDim
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                            Item { Layout.fillWidth: true }
                        }
                        CoreBar { Layout.fillWidth: true; barHeight: 3
                            value: Services.ThermalService.coolantAvailable ? Math.min(100, Services.ThermalService.coolantTemp) : 0 }
                    }
                }

                // NVMe primary
                Rectangle {
                    Layout.fillWidth: true; height: 80
                    color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
                    ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 4
                        Text { text: "NVMe PRIMARY"; color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                        RowLayout { spacing: 3
                            Text { text: Services.ThermalService.nvmeTemp > 0 ? Services.ThermalService.nvmeTemp.toFixed(1) : "--"
                                color: root.tempTier(Services.ThermalService.nvmeTemp)
                                font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 18; font.bold: true }
                            Text { text: "°C"; color: Config.ThemeConfig.colors.textDim
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                            Item { Layout.fillWidth: true }
                        }
                        CoreBar { Layout.fillWidth: true; barHeight: 3
                            value: Services.ThermalService.nvmeTemp > 0 ? Math.min(100, Services.ThermalService.nvmeTemp) : 0
                            barColor: Config.ThemeConfig.colors.primary }
                    }
                }

                // storage pool
                Rectangle {
                    Layout.fillWidth: true; height: 80
                    color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
                    ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 4
                        Text { text: "STORAGE POOL"; color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                        RowLayout { spacing: 3
                            Text { text: Math.round(Services.CoreEngineService.diskPct) + "%"
                                color: Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 18; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text { text: Services.CoreEngineService.diskUsedTB.toFixed(2) + "/" + Services.CoreEngineService.diskTotalTB.toFixed(1) + "T"
                                color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                        }
                        CoreBar { Layout.fillWidth: true; barHeight: 3
                            value: Services.CoreEngineService.diskPct; barColor: Config.ThemeConfig.colors.warning }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "COOLANT"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                Text { text: Services.ThermalService.coolantAvailable ? "OPTIMAL" : "NO SENSOR"
                    color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
                Item { Layout.fillWidth: true }
                Text { text: "NVMe"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                Text { text: Services.ThermalService.nvmeTemp > 0 ? "GEN4 // ACTIVE" : "NOT FOUND"
                    color: Config.ThemeConfig.colors.primary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
            }
        }
    }
}
