// =============================================================================
// CoreMemoryEnvPane.qml — Memory + Environment + Storage (Core; Shibumi)
// =============================================================================
// Fixed composition (§6.1 — no scrolling), tokenized per DESIGN_TOKENS:
//   ROW 1: MEMORY (capacity, meter, RAM history, available/swap tiles)
//        | ENVIRONMENT (liquid coolant + NVMe sensor tiles)
//   ROW 2: STORAGE — every real mounted filesystem (CoreEngineService.disks),
//          data-driven from df; new drives appear with no code change.
// Tier ramps delegate to ThemeConfig.tierColor (cool → warm → hot).
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

ColumnLayout {
    id: root
    spacing: Config.ControlConfig.space3

    // Tier ramps delegate to ThemeConfig.tierColor — thresholds stay here,
    // colour mapping is centralized so a theme swap retints every ramp.
    function tempTier(t) { return Config.ThemeConfig.tierColor(t, 55, 75) }
    function diskTier(p) { return Config.ThemeConfig.tierColor(p, 70, 85) }
    // "/" → "SYSTEM"; "/mnt/WD_BLACK-500GB" → "WD_BLACK-500GB"
    function driveLabel(mount) {
        return mount === "/" ? "SYSTEM" : (mount.split("/").pop() || mount)
    }

    // shared metric tile (value + unit + optional meter)
    component MetricTile: Rectangle {
        property string label: ""
        property string value: "—"
        property string unit: ""
        property color valueColor: Config.ThemeConfig.colors.text
        property real meterValue: -1        // <0 hides the meter
        property color meterColor: Config.ControlConfig.accent
        Layout.fillWidth: true; Layout.preferredHeight: 56
        radius: Config.ControlConfig.radiusPill
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
        border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
        ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 3
            Text { text: label; color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8 }
            RowLayout { spacing: 3
                Text { text: value; color: valueColor
                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 16; font.bold: true }
                Text { visible: unit !== ""; text: unit; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
            }
            CoreBar { Layout.fillWidth: true; barHeight: 3; visible: meterValue >= 0
                value: meterValue; barColor: meterColor }
        }
    }

    // ── ROW 1: Memory + Environment ─────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Config.ControlConfig.space3

        // ── MEMORY ───────────────────────────────────────────────────────────
        CoreCard {
            accent: Config.ThemeConfig.colors.warning
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: Config.ControlConfig.space2

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "MEMORY"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                    Item { Layout.fillWidth: true }
                    Rectangle { radius: Config.ControlConfig.radiusSmall
                        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.warning, 0.12)
                        border.color: Config.ThemeConfig.colors.warning; border.width: 1
                        height: 18; width: memBadge.implicitWidth + 12
                        Text { id: memBadge; anchors.centerIn: parent; text: "ECC"
                            color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true } }
                }

                // capacity readout + utilization bar
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: Services.CoreEngineService.ramTotalGB.toFixed(0) + " GB SYSTEM RAM"
                        color: Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily
                        font.pixelSize: 16; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { text: Math.round(Services.CoreEngineService.ramPct) + "% USED"
                        color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono
                        font.pixelSize: 10; font.bold: true }
                }
                CoreBar { Layout.fillWidth: true; barHeight: 8; value: Services.CoreEngineService.ramPct; barColor: Config.ThemeConfig.colors.warning }

                // 2-min RAM history — service-owned ring buffer, primary line
                // so the series reads the same as in the CPU LOAD HISTORY chart.
                ColumnLayout { Layout.fillWidth: true; spacing: 4
                    RowLayout { Layout.fillWidth: true
                        Text { text: "RAM HISTORY"; color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                        Item { Layout.fillWidth: true }
                        Text { text: "2 MIN"; color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.letterSpacing: 0.8 }
                    }
                    CoreSparkline { Layout.fillWidth: true; Layout.preferredHeight: 40
                        points: Services.CoreEngineService.memoryHistory
                        lineColor: Config.ThemeConfig.colors.primary
                        fixedMaximum: 100 }
                }

                // available + swap metric tiles
                RowLayout {
                    Layout.fillWidth: true; spacing: Config.ControlConfig.space2
                    MetricTile { label: "Available"
                        value: (Services.CoreEngineService.ramTotalGB - Services.CoreEngineService.ramUsedGB).toFixed(1); unit: "GB" }
                    MetricTile { label: "Swap"
                        value: Services.CoreEngineService.swapUsedGB.toFixed(1)
                        unit: "/ " + Services.CoreEngineService.swapTotalGB.toFixed(0) + " GB"
                        valueColor: Config.ControlConfig.accent }
                }

                // compact used/swap readout line
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "USED " + Services.CoreEngineService.ramUsedGB.toFixed(1) + " GB"
                        color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: "SWAP " + Math.round(Services.CoreEngineService.swapPct) + "%"
                        color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                }
            }
        }

        // ── ENVIRONMENT ─────────────────────────────────────────────────────
        CoreCard {
            accent: Config.ControlConfig.accent
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: Config.ControlConfig.space2

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "ENVIRONMENT"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                    Item { Layout.fillWidth: true }
                    RowLayout { spacing: 5
                        Rectangle { width: 8; height: 8; radius: 4; color: Config.ThemeConfig.colors.success
                            SequentialAnimation on opacity { loops: Animation.Infinite; running: Config.SharedState.dashboardVisible
                                NumberAnimation { to: 0.3; duration: 700 } NumberAnimation { to: 1; duration: 700 } } }
                        Text { text: "SENSORS LIVE"; color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10 }
                    }
                }

                // coolant + NVMe sensor tiles (true environmental sensors)
                RowLayout {
                    Layout.fillWidth: true; spacing: Config.ControlConfig.space2

                    MetricTile { label: "Liquid Coolant"
                        value: Services.ThermalService.coolantAvailable ? Services.ThermalService.coolantTemp.toFixed(1) : "--"; unit: "°C"
                        valueColor: root.tempTier(Services.ThermalService.coolantTemp)
                        meterValue: Services.ThermalService.coolantAvailable ? Math.min(100, Services.ThermalService.coolantTemp) : -1
                        meterColor: root.tempTier(Services.ThermalService.coolantTemp)
                        Layout.preferredHeight: 64 }

                    MetricTile { label: "NVMe"
                        value: Services.ThermalService.nvmeTemp > 0 ? Services.ThermalService.nvmeTemp.toFixed(1) : "--"; unit: "°C"
                        valueColor: root.tempTier(Services.ThermalService.nvmeTemp)
                        meterValue: Services.ThermalService.nvmeTemp > 0 ? Math.min(100, Services.ThermalService.nvmeTemp) : -1
                        meterColor: Config.ThemeConfig.colors.primary
                        Layout.preferredHeight: 64 }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: Services.ThermalService.coolantAvailable ? "COOLANT OPTIMAL" : "NO COOLANT SENSOR"
                        color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: Services.ThermalService.nvmeTemp > 0 ? "NVMe GEN4" : "NVMe NOT FOUND"
                        color: Config.ThemeConfig.colors.primary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    // ── ROW 2: Storage ──────────────────────────────────────────────────
    CoreCard {
        accent: Config.ThemeConfig.colors.primary
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true; spacing: Config.ControlConfig.space2

            RowLayout {
                Layout.fillWidth: true
                Text { text: "STORAGE"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                Item { Layout.fillWidth: true }
                Rectangle { radius: Config.ControlConfig.radiusSmall
                    color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.primary, 0.12)
                    border.color: Config.ThemeConfig.colors.primary; border.width: 1
                    height: 18; width: drvCount.implicitWidth + 12
                    Text { id: drvCount; anchors.centerIn: parent; text: Services.CoreEngineService.disks.length + " DRIVES"
                        color: Config.ThemeConfig.colors.primary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true } }
            }

            // empty state (df hasn't returned yet — clears within the first tick)
            Text { visible: Services.CoreEngineService.disks.length === 0
                Layout.fillWidth: true
                text: "READING DRIVES …"; color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter }

            RowLayout {
                Layout.fillWidth: true; spacing: Config.ControlConfig.space2
                Repeater {
                    model: Services.CoreEngineService.disks
                    delegate: Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 88
                        radius: Config.ControlConfig.radiusPill
                        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
                        border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
                        Rectangle { anchors.left: parent.left; anchors.leftMargin: 6
                            anchors.top: parent.top; anchors.topMargin: 8
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                            width: 3; radius: 1.5; color: root.diskTier(modelData.pct) }
                        ColumnLayout { anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 8
                            anchors.topMargin: 8; anchors.bottomMargin: 8; spacing: 4
                            RowLayout { Layout.fillWidth: true
                                Text { text: root.driveLabel(modelData.mount); color: Config.ThemeConfig.colors.text
                                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 12; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                                Text { text: modelData.device; color: Config.ThemeConfig.colors.textDim
                                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
                            }
                            RowLayout { Layout.fillWidth: true; spacing: 4
                                Text { text: Math.round(modelData.pct) + "%"; color: root.diskTier(modelData.pct)
                                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 16; font.bold: true }
                                Text { text: modelData.usedGB.toFixed(1) + "G used"
                                    color: Config.ThemeConfig.colors.text; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
                                Item { Layout.fillWidth: true }
                                Text { text: modelData.availGB.toFixed(0) + "G free"
                                    color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
                            }
                            CoreBar { Layout.fillWidth: true; barHeight: 3; value: modelData.pct; barColor: root.diskTier(modelData.pct) }
                            RowLayout { Layout.fillWidth: true
                                Text { text: modelData.totalGB.toFixed(0) + "G total"; color: Config.ThemeConfig.colors.textDim
                                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
                                Item { Layout.fillWidth: true }
                                Text { text: modelData.fstype.toUpperCase(); color: Config.ThemeConfig.colors.textDim
                                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                            }
                        }
                    }
                }
            }
        }
    }
}
