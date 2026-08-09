// =============================================================================
// CoreMemoryEnvPane.qml — Memory Bank + Environmental + Storage Drives (Core)
// =============================================================================
// Three HudCard modules in the tactical-HUD aesthetic (sharp borders, mono
// headers, black-40% metric tiles, display-font readouts). Colours are live
// ThemeConfig tokens; tempTier/diskTier shift cool → warm → hot by value.
//
//   1. MEMORY_BANK    — RAM capacity, used%, available, swap
//   2. ENVIRONMENTAL  — liquid coolant + NVMe temps (true sensors)
//   3. STORAGE_DRIVES — every real mounted filesystem (CoreEngineService.disks)
//
// Storage moved out of "environmental" into its own card so each physical
// drive (system NVMe + mounted data drives) is shown individually. The drive
// list is data-driven from df — new drives appear with no code change.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

ColumnLayout {
    id: root
    spacing: 14

    // cool → warm → hot severity colour, mapped to live theme tokens.
    function tempTier(t) {
        if (t >= 75) return Config.ThemeConfig.colors.error
        if (t >= 55) return Config.ThemeConfig.colors.warning
        return Config.ThemeConfig.colors.secondary
    }
    function diskTier(p) {
        if (p >= 85) return Config.ThemeConfig.colors.error
        if (p >= 70) return Config.ThemeConfig.colors.warning
        return Config.ThemeConfig.colors.secondary
    }
    // "/" → "SYSTEM"; "/mnt/WD_BLACK-500GB" → "WD_BLACK-500GB"
    function driveLabel(mount) {
        return mount === "/" ? "SYSTEM" : (mount.split("/").pop() || mount)
    }

    // ── ROW 1: Memory Bank + Environmental ───────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 14

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
                            SequentialAnimation on opacity { loops: Animation.Infinite; running: Config.SharedState.dashboardVisible
                                NumberAnimation { to: 0.3; duration: 700 } NumberAnimation { to: 1; duration: 700 } } }
                        Text { text: "SENSORS LIVE"; color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                    }
                }

                // coolant + NVMe metric tiles (true environmental sensors)
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

    // ── ROW 2: Storage Drives ────────────────────────────────────────────
    HudCard {
        accent: Config.ThemeConfig.colors.primary
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true; spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text { text: "STORAGE_DRIVES"; color: Config.ThemeConfig.colors.primary
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5 }
                Item { Layout.fillWidth: true }
                Rectangle { radius: 0; border.color: Config.ThemeConfig.colors.primary; border.width: 1
                    height: 14; width: drvCount.implicitWidth + 10
                    Text { id: drvCount; anchors.centerIn: parent; text: Services.CoreEngineService.disks.length + " DRIVES"
                        color: Config.ThemeConfig.colors.primary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 7; font.bold: true } }
            }

            // empty state (df hasn't returned yet — clears within the first tick)
            Text { visible: Services.CoreEngineService.disks.length === 0
                Layout.fillWidth: true
                text: "READING DRIVES …"; color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                horizontalAlignment: Text.AlignHCenter }

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Repeater {
                    model: Services.CoreEngineService.disks
                    delegate: Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 92
                        color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
                        Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 2
                            color: root.diskTier(modelData.pct) }
                        ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 4
                            RowLayout { Layout.fillWidth: true
                                Text { text: root.driveLabel(modelData.mount); color: Config.ThemeConfig.colors.text
                                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 11; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                                Text { text: modelData.device; color: Config.ThemeConfig.colors.textDim
                                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                            }
                            RowLayout { Layout.fillWidth: true; spacing: 3
                                Text { text: Math.round(modelData.pct) + "%"; color: root.diskTier(modelData.pct)
                                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 18; font.bold: true }
                                Text { text: "·"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                                Text { text: modelData.usedGB.toFixed(1) + "G used"
                                    color: Config.ThemeConfig.colors.text; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                                Item { Layout.fillWidth: true }
                                Text { text: modelData.availGB.toFixed(0) + "G free"
                                    color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                            }
                            CoreBar { Layout.fillWidth: true; barHeight: 3; value: modelData.pct; barColor: root.diskTier(modelData.pct) }
                            RowLayout { Layout.fillWidth: true
                                Text { text: modelData.totalGB.toFixed(0) + "G total"; color: Config.ThemeConfig.colors.textDim
                                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 7 }
                                Item { Layout.fillWidth: true }
                                Text { text: modelData.fstype.toUpperCase(); color: Config.ThemeConfig.colors.textDim
                                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 7; font.bold: true }
                            }
                        }
                    }
                }
            }
        }
    }
}
