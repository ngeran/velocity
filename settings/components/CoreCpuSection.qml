// =============================================================================
// CoreCpuSection.qml — CPU tactical array (Core tab, Processors)
// =============================================================================
// Redesigned to the HudCard aesthetic used by CoreOverviewPane, adapting the
// "NixOS CPU Tactical Array" arrangement:
//   1. SPEC STRIP        — 4 left-accented tiles (array / clock / temp / load)
//   2. MAIN SPLIT        — global-load gauge + 2×2 metric tiles | per-core grid
//   3. STATUS FOOTER     — scheduler / turbo / threads pills + refresh
// All values are live telemetry (CoreEngineService.perCoreLoad / cpuUsage /
// cpuGhz + ThermalService.cpuTemp). Colours are ThemeConfig tokens; tempTier /
// loadTier ramp cool → warm → hot so busy cores and high temps glow.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

ColumnLayout {
    id: root
    spacing: 12

    readonly property int coreCount: Services.CoreEngineService.perCoreLoad.length

    function tempTier(t) {
        if (t >= 75) return Config.ThemeConfig.colors.error
        if (t >= 55) return Config.ThemeConfig.colors.warning
        return Config.ThemeConfig.colors.secondary
    }
    function loadTier(v) {
        if (v >= 85) return Config.ThemeConfig.colors.error
        if (v >= 50) return Config.ThemeConfig.colors.warning
        return Config.ThemeConfig.colors.secondary
    }
    function schedLabel(v) { return v > 80 ? "HIGH" : (v > 40 ? "ACTIVE" : "OPTIMIZED") }

    // ── 1. SPEC STRIP ───────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true; spacing: 8

        Rectangle {        // PROCESSOR ARRAY
            Layout.fillWidth: true; Layout.preferredHeight: 54
            color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
            Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 2; color: Config.ThemeConfig.colors.primary }
            ColumnLayout { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; anchors.topMargin: 8; anchors.bottomMargin: 8; spacing: 2
                Text { text: "PROCESSOR ARRAY"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.0 }
                Text { text: root.coreCount + "-CORE"; color: Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 15; font.bold: true }
            }
        }
        Rectangle {        // BOOST CLOCK
            Layout.fillWidth: true; Layout.preferredHeight: 54
            color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
            Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 2; color: Config.ThemeConfig.colors.secondary }
            ColumnLayout { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; anchors.topMargin: 8; anchors.bottomMargin: 8; spacing: 2
                Text { text: "BOOST CLOCK"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.0 }
                Text { text: Services.CoreEngineService.cpuGhz.toFixed(2) + " GHz"; color: Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 15; font.bold: true }
            }
        }
        Rectangle {        // PACKAGE TEMP
            Layout.fillWidth: true; Layout.preferredHeight: 54
            color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
            Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 2; color: root.tempTier(Services.ThermalService.cpuTemp) }
            ColumnLayout { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; anchors.topMargin: 8; anchors.bottomMargin: 8; spacing: 2
                Text { text: "PACKAGE TEMP"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.0 }
                Text { text: Math.round(Services.ThermalService.cpuTemp) + " °C"; color: root.tempTier(Services.ThermalService.cpuTemp); font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 15; font.bold: true }
            }
        }
        Rectangle {        // AVG LOAD
            Layout.fillWidth: true; Layout.preferredHeight: 54
            color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
            Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 2; color: root.loadTier(Services.CoreEngineService.cpuUsage) }
            ColumnLayout { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; anchors.topMargin: 8; anchors.bottomMargin: 8; spacing: 2
                Text { text: "AVG LOAD"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.0 }
                Text { text: Math.round(Services.CoreEngineService.cpuUsage) + " %"; color: root.loadTier(Services.CoreEngineService.cpuUsage); font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 15; font.bold: true }
            }
        }
    }

    // ── 2. MAIN SPLIT: gauge+metrics (left) | per-core array (right) ─────
    RowLayout {
        Layout.fillWidth: true; spacing: 12

        // LEFT — global utilisation gauge + 2×2 metric tiles
        HudCard {
            accent: Config.ThemeConfig.colors.primary
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "LOAD_VECTOR_GLOBAL"; color: Config.ThemeConfig.colors.primary
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5 }
                    Item { Layout.fillWidth: true }
                    Rectangle { width: 7; height: 7; radius: 4; color: Config.ThemeConfig.colors.success
                        SequentialAnimation on opacity { loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 700 } NumberAnimation { to: 1; duration: 700 } } }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    HudGauge {
                        value: Services.CoreEngineService.cpuUsage; max: 100; size: 140
                        accent: root.loadTier(Services.CoreEngineService.cpuUsage)
                        label: "TOTAL UTILIZATION"; unit: "%"
                    }
                    Item { Layout.fillWidth: true }
                }

                GridLayout {
                    Layout.fillWidth: true; columns: 2; rowSpacing: 8; columnSpacing: 8

                    Rectangle {   // PEAK TEMPERATURE
                        Layout.fillWidth: true; Layout.preferredHeight: 62
                        color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
                        ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 4
                            Text { text: "PEAK TEMPERATURE"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                            RowLayout { spacing: 2
                                Text { text: Services.ThermalService.cpuTemp.toFixed(1); color: root.tempTier(Services.ThermalService.cpuTemp)
                                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 18; font.bold: true }
                                Text { text: "°C"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                                Item { Layout.fillWidth: true }
                            }
                            CoreBar { Layout.fillWidth: true; barHeight: 3; value: Services.ThermalService.cpuTemp; barColor: root.tempTier(Services.ThermalService.cpuTemp) }
                        }
                    }
                    Rectangle {   // UTILIZATION
                        Layout.fillWidth: true; Layout.preferredHeight: 62
                        color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
                        ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 4
                            Text { text: "UTILIZATION"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                            RowLayout { spacing: 2
                                Text { text: Math.round(Services.CoreEngineService.cpuUsage); color: root.loadTier(Services.CoreEngineService.cpuUsage)
                                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 18; font.bold: true }
                                Text { text: "%"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                                Item { Layout.fillWidth: true }
                            }
                            CoreBar { Layout.fillWidth: true; barHeight: 3; value: Services.CoreEngineService.cpuUsage; barColor: root.loadTier(Services.CoreEngineService.cpuUsage) }
                        }
                    }
                    Rectangle {   // BOOST CLOCK
                        Layout.fillWidth: true; Layout.preferredHeight: 62
                        color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
                        ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 4
                            Text { text: "BOOST CLOCK"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                            RowLayout { spacing: 2
                                Text { text: Services.CoreEngineService.cpuGhz.toFixed(2); color: Config.ThemeConfig.colors.secondary
                                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 18; font.bold: true }
                                Text { text: "GHz"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                                Item { Layout.fillWidth: true }
                            }
                        }
                    }
                    Rectangle {   // LOGICAL CORES
                        Layout.fillWidth: true; Layout.preferredHeight: 62
                        color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
                        ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 4
                            Text { text: "LOGICAL CORES"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                            RowLayout { spacing: 2
                                Text { text: root.coreCount; color: Config.ThemeConfig.colors.primary
                                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 18; font.bold: true }
                                Text { text: "thr"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                                Item { Layout.fillWidth: true }
                            }
                        }
                    }
                }
            }
        }

        // RIGHT — per-core tactical array
        HudCard {
            accent: Config.ThemeConfig.colors.secondary
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "TACTICAL_CORE_ARRAY"; color: Config.ThemeConfig.colors.secondary
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5 }
                    Item { Layout.fillWidth: true }
                    Rectangle { radius: 0; border.color: Config.ThemeConfig.colors.secondary; border.width: 1
                        height: 14; width: arrNodes.implicitWidth + 10
                        Text { id: arrNodes; anchors.centerIn: parent; text: root.coreCount + " NODES"
                            color: Config.ThemeConfig.colors.secondary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 7; font.bold: true } }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: root.coreCount >= 24 ? 6 : (root.coreCount >= 12 ? 4 : 3)
                    rowSpacing: 6; columnSpacing: 6
                    Repeater {
                        model: Services.CoreEngineService.perCoreLoad
                        delegate: Rectangle {
                            id: coreTile
                            property real load: modelData
                            Layout.fillWidth: true; Layout.preferredHeight: 46
                            color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
                            ColumnLayout { anchors.fill: parent; anchors.margins: 6; spacing: 4
                                RowLayout { Layout.fillWidth: true
                                    Text { text: "CORE_" + (index + 1).toString().padStart(2, "0"); color: Config.ThemeConfig.colors.textDim
                                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
                                    Item { Layout.fillWidth: true }
                                    Text { text: Math.round(coreTile.load) + "%"; color: root.loadTier(coreTile.load)
                                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
                                }
                                CoreBar { Layout.fillWidth: true; barHeight: 3; value: coreTile.load; barColor: root.loadTier(coreTile.load) }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── 3. STATUS FOOTER ────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true; spacing: 8

        Rectangle {        // SCHEDULER
            height: 22; width: schRow.implicitWidth + 16
            color: Qt.rgba(1, 1, 1, 0.03); border.color: Config.ThemeConfig.colors.border; border.width: 1
            RowLayout { id: schRow; anchors.centerIn: parent; spacing: 6
                Rectangle { width: 6; height: 6; radius: 3; color: root.loadTier(Services.CoreEngineService.cpuUsage) }
                Text { text: "SCHEDULER"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                Text { text: root.schedLabel(Services.CoreEngineService.cpuUsage); color: root.loadTier(Services.CoreEngineService.cpuUsage)
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
            }
        }
        Rectangle {        // TURBO
            height: 22; width: turbRow.implicitWidth + 16
            color: Qt.rgba(1, 1, 1, 0.03); border.color: Config.ThemeConfig.colors.border; border.width: 1
            RowLayout { id: turbRow; anchors.centerIn: parent; spacing: 6
                Rectangle { width: 6; height: 6; radius: 3; color: Services.CoreEngineService.cpuGhz > 0 ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.textDim }
                Text { text: "TURBO"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                Text { text: Services.CoreEngineService.cpuGhz > 0 ? "ACTIVE" : "IDLE"
                    color: Services.CoreEngineService.cpuGhz > 0 ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
            }
        }
        Rectangle {        // THREADS
            height: 22; width: smtRow.implicitWidth + 16
            color: Qt.rgba(1, 1, 1, 0.03); border.color: Config.ThemeConfig.colors.border; border.width: 1
            RowLayout { id: smtRow; anchors.centerIn: parent; spacing: 6
                Rectangle { width: 6; height: 6; radius: 3; color: Config.ThemeConfig.colors.secondary }
                Text { text: "THREADS"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                Text { text: root.coreCount; color: Config.ThemeConfig.colors.text; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
            }
        }

        Item { Layout.fillWidth: true }
        Text { text: "REFRESH 1.0s"; color: Config.ThemeConfig.colors.textDim
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.letterSpacing: 1 }
    }
}
