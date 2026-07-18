// =============================================================================
// CoreOverviewPane.qml — tactical-HUD at-a-glance overview (Core tab, Overview)
// =============================================================================
// Status bar (CoreStatusHeader) + a 2×2 grid of rich HudCard modules, after the
// NeuralOS tactical-dashboard reference — adapted to real telemetry and the
// live theme:
//   1. MAIN_PROCESSOR_ARRAY  — core count/boost, package temp, 4 sample cores
//   2. MEMORY_STORAGE_MATRIX — RAM bar, NVMe temp, data-pool utilisation
//   3. THERMAL_DYNAMICS      — CPU/GPU radial gauges + a live CPU-usage spark
//   4. LCD_REMOTE_MONITOR    — read-only live mini-LCD preview + status
//
// Colours are ThemeConfig tokens; tempTier() shifts cool→warm→hot by value
// (the tactical multi-hue look via semantic tokens, recolouring with the theme).
// Fonts: Inter/JBM for display numbers, JetBrains Mono for labels. Full detail
// for each domain lives on its dedicated page (Processors / Memory / etc.).
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
    function pad2(n) { return ("0" + n).slice(-2) }

    // Four spread sample-core indices (0, n/4, n/2, 3n/4) — reactive only to
    // core-count changes, so the Repeater delegates are stable across the 1s
    // value updates (each delegate binds perCoreLoad[index] live).
    readonly property var coreSample: {
        var n = Services.CoreEngineService.perCoreLoad.length
        if (n === 0) return [0, 0, 0, 0]
        return [0, Math.floor(n / 4), Math.floor(n / 2), Math.floor(3 * n / 4)]
    }

    CoreStatusHeader { Layout.fillWidth: true }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        rowSpacing: 12; columnSpacing: 12

        // ── 1. MAIN PROCESSOR ARRAY ─────────────────────────────────────────
        HudCard {
            accent: Config.ThemeConfig.colors.secondary
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10

                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Text { text: "MAIN_PROCESSOR_ARRAY"; color: Config.ThemeConfig.colors.secondary
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5 }
                    Item { Layout.fillWidth: true }
                    ColumnLayout { spacing: 0
                        Text { text: "PACKAGE TEMP"; color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; Layout.alignment: Qt.AlignRight }
                        Text { text: Math.round(Services.ThermalService.cpuTemp) + "°"
                            color: root.tempTier(Services.ThermalService.cpuTemp)
                            font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 14; font.bold: true
                            Layout.alignment: Qt.AlignRight }
                    }
                }

                Text {
                    text: Services.CoreEngineService.perCoreLoad.length + "-CORE  //  "
                          + Services.CoreEngineService.cpuGhz.toFixed(2) + " GHz BOOST"
                    color: Config.ThemeConfig.colors.text
                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 16; font.bold: true
                }

                // 4 sample core-load tiles
                GridLayout {
                    Layout.fillWidth: true; columns: 2; rowSpacing: 6; columnSpacing: 6
                    Repeater {
                        model: root.coreSample
                        delegate: Rectangle {
                            id: coreTile
                            Layout.fillWidth: true; height: 42
                            color: Qt.rgba(0, 0, 0, 0.4)
                            border.color: Config.ThemeConfig.colors.border; border.width: 1
                            property real coreLoad: Services.CoreEngineService.perCoreLoad[modelData] || 0
                            ColumnLayout { anchors.fill: parent; anchors.margins: 6; spacing: 3
                                RowLayout { Layout.fillWidth: true
                                    Text { text: "CORE_" + root.pad2(modelData + 1); color: Config.ThemeConfig.colors.textDim
                                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
                                    Item { Layout.fillWidth: true }
                                    Text { text: Math.round(coreTile.coreLoad) + "%"; color: Config.ThemeConfig.colors.secondary
                                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                                }
                                CoreBar { Layout.fillWidth: true; barHeight: 3; value: coreTile.coreLoad }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "AVG LOAD"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                    Text { text: Math.round(Services.CoreEngineService.cpuUsage) + "%"; color: Config.ThemeConfig.colors.secondary
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: "SCHEDULER"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                    Text { text: "OPTIMIZED"; color: Config.ThemeConfig.colors.success
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
                }
            }
        }

        // ── 2. MEMORY / STORAGE MATRIX ──────────────────────────────────────
        HudCard {
            accent: Config.ThemeConfig.colors.warning
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "MEMORY_STORAGE_MATRIX"; color: Config.ThemeConfig.colors.warning
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5 }
                    Item { Layout.fillWidth: true }
                    Rectangle { radius: 0; border.color: Config.ThemeConfig.colors.warning; border.width: 1
                        height: 14; width: ecW.implicitWidth + 10
                        Text { id: ecW; anchors.centerIn: parent; text: "ECC_ENCRYPTED"
                            color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 7; font.bold: true } }
                }

                // RAM capacity bar
                ColumnLayout { Layout.fillWidth: true; spacing: 4
                    RowLayout { Layout.fillWidth: true
                        Text { text: "SYSTEM RAM (" + Services.CoreEngineService.ramTotalGB.toFixed(0) + "G)"
                            color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                        Item { Layout.fillWidth: true }
                        Text { text: Math.round(Services.CoreEngineService.ramPct) + "% USED"
                            color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
                    }
                    CoreBar { Layout.fillWidth: true; barHeight: 8; value: Services.CoreEngineService.ramPct; barColor: Config.ThemeConfig.colors.warning }
                    RowLayout { Layout.fillWidth: true
                        Text { text: "USED " + Services.CoreEngineService.ramUsedGB.toFixed(1) + "G"
                            color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                        Item { Layout.fillWidth: true }
                        Text { text: "SWAP " + Services.CoreEngineService.swapUsedGB.toFixed(1) + "/" + Services.CoreEngineService.swapTotalGB.toFixed(0) + "G"
                            color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                    }
                }

                // NVMe + Data Pool
                RowLayout { Layout.fillWidth: true; spacing: 8
                    Rectangle {
                        Layout.fillWidth: true; height: 58
                        color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
                        ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 3
                            Text { text: "NVMe PRIMARY (Gen4)"; color: Config.ThemeConfig.colors.textDim
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                            RowLayout { Layout.fillWidth: true; spacing: 6
                                Text { text: (Services.ThermalService.nvmeTemp > 0 ? Services.ThermalService.nvmeTemp.toFixed(0) : "--") + "°C"
                                    color: Config.ThemeConfig.colors.secondary; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 18; font.bold: true }
                                Item { Layout.fillWidth: true }
                                Rectangle { border.color: Config.ThemeConfig.colors.secondary; border.width: 1; height: 12; width: nvW.implicitWidth + 8
                                    Text { id: nvW; anchors.centerIn: parent; text: Services.ThermalService.nvmeTemp > 0 ? "HEALTHY" : "N/A"
                                        color: Config.ThemeConfig.colors.secondary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 7; font.bold: true } }
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: 58
                        color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
                        ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 3
                            Text { text: "DATA POOL"; color: Config.ThemeConfig.colors.textDim
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                            RowLayout { Layout.fillWidth: true; spacing: 6
                                Text { text: Math.round(Services.CoreEngineService.diskPct) + "%"
                                    color: Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 18; font.bold: true }
                                Item { Layout.fillWidth: true }
                                Text { text: Services.CoreEngineService.diskUsedTB.toFixed(2) + "/" + Services.CoreEngineService.diskTotalTB.toFixed(1) + "T"
                                    color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "SWAP"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                    Text { text: Math.round(Services.CoreEngineService.swapPct) + "%"; color: Config.ThemeConfig.colors.secondary
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: "POOL"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                    Text { text: Math.round(Services.CoreEngineService.diskPct) + "%"; color: Config.ThemeConfig.colors.warning
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
                }
            }
        }

        // ── 3. THERMAL DYNAMICS ─────────────────────────────────────────────
        HudCard {
            accent: Config.ThemeConfig.colors.error
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "THERMAL_DYNAMICS"; color: Config.ThemeConfig.colors.error
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5 }
                    Item { Layout.fillWidth: true }
                    RowLayout { spacing: 4
                        Rectangle { width: 6; height: 6; radius: 3; color: Config.ThemeConfig.colors.secondary }
                        Rectangle { width: 6; height: 6; radius: 3; color: Config.ThemeConfig.colors.error }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 16
                    Item { Layout.fillWidth: true }
                    HudGauge {
                        value: Services.ThermalService.cpuTemp; max: 100; size: 88
                        accent: root.tempTier(Services.ThermalService.cpuTemp); label: "CPU PACKAGE"
                    }
                    HudGauge {
                        value: Services.GpuService.temp; max: 100; size: 88
                        accent: root.tempTier(Services.GpuService.temp); label: "GPU CORE"
                    }
                    Item { Layout.fillWidth: true }
                }

                ColumnLayout { Layout.fillWidth: true; spacing: 4
                    RowLayout { Layout.fillWidth: true
                        Text { text: "INFERENCE CYCLE FLOW"; color: Config.ThemeConfig.colors.secondary
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                        Item { Layout.fillWidth: true }
                        Text { text: "REAL-TIME"; color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                    }
                    HudSpark { Layout.fillWidth: true; Layout.preferredHeight: 48
                        value: Services.CoreEngineService.cpuUsage; max: 100; accent: Config.ThemeConfig.colors.secondary }
                }
            }
        }

        // ── 4. LCD REMOTE MONITOR ───────────────────────────────────────────
        HudCard {
            accent: Config.ThemeConfig.colors.success
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "LCD_REMOTE_MONITOR"; color: Config.ThemeConfig.colors.success
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5 }
                    Item { Layout.fillWidth: true }
                    RowLayout { spacing: 5
                        Rectangle { width: 8; height: 8; radius: 4; color: Config.ThemeConfig.colors.success
                            SequentialAnimation on opacity { loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 700 } NumberAnimation { to: 1; duration: 700 } } }
                        Text { text: "FEED LIVE"; color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 12

                    // mini LCD mock — live stat cluster (read-only, no config coupling)
                    Rectangle {
                        width: 116; height: 138; radius: 8
                        color: "#000000"; border.color: Config.ThemeConfig.colors.border; border.width: 1
                        Layout.alignment: Qt.AlignVCenter
                        Column { anchors.centerIn: parent; spacing: 6
                            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 26; height: 2; radius: 1; color: Config.ThemeConfig.colors.border }
                            Text { anchors.horizontalCenter: parent.horizontalCenter
                                text: Math.round(Services.ThermalService.cpuTemp) + "°"
                                color: Config.ThemeConfig.colors.warning; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 26; font.bold: true }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "MAIN TEMP"
                                color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 7 }
                            Grid {
                                anchors.horizontalCenter: parent.horizontalCenter; columns: 2; spacing: 8
                                Text { text: Math.round(Services.GpuService.temp) + "°"; color: Config.ThemeConfig.colors.text
                                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
                                Text { text: "GPU"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 7 }
                                Text { text: Math.round(Services.CoreEngineService.cpuUsage) + "%"; color: Config.ThemeConfig.colors.text
                                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
                                Text { text: "LOAD"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 7 }
                                Text { text: Math.round(Services.CoreEngineService.ramPct) + "%"; color: Config.ThemeConfig.colors.text
                                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
                                Text { text: "RAM"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 7 }
                                Text { text: Services.CoreEngineService.cpuGhz.toFixed(2); color: Config.ThemeConfig.colors.text
                                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
                                Text { text: "FRQ"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 7 }
                            }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "LIVE PREVIEW"
                                color: Config.ThemeConfig.colors.success; font.family: Config.ControlConfig.fontMono; font.pixelSize: 7; opacity: 0.6 }
                        }
                    }

                    // status readouts + mode legend
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 8
                        ColumnLayout { spacing: 1
                            Text { text: "LCD NODE"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                            Text { text: "DEEPCOOL"; color: Config.ThemeConfig.colors.text; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                        }
                        ColumnLayout { spacing: 1
                            Text { text: "REFRESH"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                            Text { text: "1.0s"; color: Config.ThemeConfig.colors.secondary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                        }
                        ColumnLayout { spacing: 3
                            Text { text: "MODES"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                            RowLayout { spacing: 4
                                Repeater {
                                    model: ["CPU", "GPU", "GFOCUS"]
                                    delegate: Rectangle {
                                        height: 14; width: mm.implicitWidth + 8
                                        color: index === 0 ? Config.ThemeConfig.colors.success : Qt.rgba(1, 1, 1, 0.03)
                                        border.color: index === 0 ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.border; border.width: 1
                                        Text { id: mm; anchors.centerIn: parent; text: modelData
                                            color: index === 0 ? "#000000" : Config.ThemeConfig.colors.textDim
                                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 7; font.bold: true }
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "UNIT"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                    Text { text: "CELSIUS"; color: Config.ThemeConfig.colors.secondary
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: "STATUS"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                    Text { text: "ENABLED"; color: Config.ThemeConfig.colors.success
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
                }
            }
        }
    }
}
