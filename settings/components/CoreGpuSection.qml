// =============================================================================
// CoreGpuSection.qml — GPU telemetry (Core tab, GPU)
// =============================================================================
// HudCard aesthetic — sibling of CoreCpuSection (Processors). All data comes
// from Services.GpuService, the single vendor-aware GPU module (nvidia-smi
// today; amd/intel branch stubbed for a future GPU swap). Layout mirrors the
// CPU section: SPEC STRIP → MAIN SPLIT (util gauge + sparkline + metrics |
// top GPU processes) → STATUS FOOTER. The per-process list is the
// nvtop-equivalent (nvidia-smi --query-compute-apps). Colours are ThemeConfig
// tokens; temp/load/vram tiers ramp cool → warm → hot so busy / hot /
// memory-full states glow.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

ColumnLayout {
    id: root
    spacing: 12

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
    function vramTier(v) {
        if (v >= 90) return Config.ThemeConfig.colors.error
        if (v >= 70) return Config.ThemeConfig.colors.warning
        return Config.ThemeConfig.colors.secondary
    }

    // processes[] is sorted desc by memMiB in GpuService → [0] is the max.
    readonly property real procMaxMem: (Services.GpuService.processes.length > 0
        ? Services.GpuService.processes[0].memMiB : 1) || 1

    // ── 1. SPEC STRIP ───────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true; spacing: 8

        Rectangle {        // DEVICE
            Layout.fillWidth: true; Layout.preferredHeight: 54
            color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
            Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 2; color: Config.ThemeConfig.colors.secondary }
            ColumnLayout { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; anchors.topMargin: 8; anchors.bottomMargin: 8; spacing: 2
                Text { text: "DEVICE"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.0 }
                Text { text: Services.GpuService.present ? (Services.GpuService.name || "GPU") : "NO GPU"
                    color: Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 15; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
            }
        }
        Rectangle {        // VRAM
            Layout.fillWidth: true; Layout.preferredHeight: 54
            color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
            Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 2; color: root.vramTier(Services.GpuService.vramPct) }
            ColumnLayout { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; anchors.topMargin: 8; anchors.bottomMargin: 8; spacing: 2
                Text { text: "VRAM"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.0 }
                Text { text: Services.GpuService.vramUsedGB.toFixed(1) + "/" + Services.GpuService.vramTotalGB.toFixed(0) + "G"; color: root.vramTier(Services.GpuService.vramPct); font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 15; font.bold: true }
            }
        }
        Rectangle {        // TEMP
            Layout.fillWidth: true; Layout.preferredHeight: 54
            color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
            Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 2; color: root.tempTier(Services.GpuService.temp) }
            ColumnLayout { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; anchors.topMargin: 8; anchors.bottomMargin: 8; spacing: 2
                Text { text: "TEMP"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.0 }
                Text { text: Math.round(Services.GpuService.temp) + " °C"; color: root.tempTier(Services.GpuService.temp); font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 15; font.bold: true }
            }
        }
        Rectangle {        // POWER
            Layout.fillWidth: true; Layout.preferredHeight: 54
            color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
            Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 2; color: root.loadTier(Services.GpuService.util) }
            ColumnLayout { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; anchors.topMargin: 8; anchors.bottomMargin: 8; spacing: 2
                Text { text: "POWER"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.0 }
                Text { text: Services.GpuService.powerW.toFixed(0) + " W"; color: Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 15; font.bold: true }
            }
        }
    }

    // ── 2. MAIN SPLIT: gauge+sparkline+metrics (left) | processes (right) ─
    RowLayout {
        Layout.fillWidth: true; spacing: 12

        // LEFT — utilization gauge + history sparkline + 2×2 metric tiles
        HudCard {
            accent: Config.ThemeConfig.colors.secondary
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "GPU_UTIL_VECTOR"; color: Config.ThemeConfig.colors.secondary
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
                        value: Services.GpuService.util; max: 100; size: 120
                        accent: root.loadTier(Services.GpuService.util)
                        label: "GPU UTILIZATION"; unit: "%"
                    }
                    Item { Layout.fillWidth: true }
                }

                // utilization history (HudSpark owns its own rolling buffer)
                ColumnLayout { Layout.fillWidth: true; spacing: 4
                    RowLayout { Layout.fillWidth: true
                        Text { text: "UTIL FLOW"; color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.0 }
                        Item { Layout.fillWidth: true }
                        Text { text: "2.0s"; color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                    }
                    HudSpark { Layout.fillWidth: true; Layout.preferredHeight: 44
                        value: Services.GpuService.util; max: 100; accent: root.loadTier(Services.GpuService.util) }
                }

                GridLayout {
                    Layout.fillWidth: true; columns: 2; rowSpacing: 8; columnSpacing: 8

                    Rectangle {   // CORE TEMP
                        Layout.fillWidth: true; Layout.preferredHeight: 62
                        color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
                        ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 4
                            Text { text: "CORE TEMP"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                            RowLayout { spacing: 2
                                Text { text: Services.GpuService.temp.toFixed(0); color: root.tempTier(Services.GpuService.temp)
                                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 18; font.bold: true }
                                Text { text: "°C"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                                Item { Layout.fillWidth: true }
                            }
                            CoreBar { Layout.fillWidth: true; barHeight: 3; value: Services.GpuService.temp; barColor: root.tempTier(Services.GpuService.temp) }
                        }
                    }
                    Rectangle {   // VRAM
                        Layout.fillWidth: true; Layout.preferredHeight: 62
                        color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
                        ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 4
                            Text { text: "VRAM"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                            RowLayout { spacing: 2
                                Text { text: Math.round(Services.GpuService.vramPct); color: root.vramTier(Services.GpuService.vramPct)
                                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 18; font.bold: true }
                                Text { text: "%"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                                Item { Layout.fillWidth: true }
                            }
                            CoreBar { Layout.fillWidth: true; barHeight: 3; value: Services.GpuService.vramPct; barColor: root.vramTier(Services.GpuService.vramPct) }
                        }
                    }
                    Rectangle {   // CLOCK
                        Layout.fillWidth: true; Layout.preferredHeight: 62
                        color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
                        ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 4
                            Text { text: "CLOCK"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                            RowLayout { spacing: 2
                                Text { text: Services.GpuService.clockMHz.toFixed(0); color: Config.ThemeConfig.colors.secondary
                                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 18; font.bold: true }
                                Text { text: "MHz"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                                Item { Layout.fillWidth: true }
                            }
                        }
                    }
                    Rectangle {   // POWER
                        Layout.fillWidth: true; Layout.preferredHeight: 62
                        color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
                        ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 4
                            Text { text: "POWER"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                            RowLayout { spacing: 2
                                Text { text: Services.GpuService.powerW.toFixed(0); color: Config.ThemeConfig.colors.text
                                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 18; font.bold: true }
                                Text { text: "W"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                                Item { Layout.fillWidth: true }
                            }
                        }
                    }
                }
            }
        }

        // RIGHT — top GPU processes (nvtop-equivalent)
        HudCard {
            accent: Config.ThemeConfig.colors.primary
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "TOP_GPU_PROCESSES"; color: Config.ThemeConfig.colors.primary
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5 }
                    Item { Layout.fillWidth: true }
                    Rectangle { radius: 0; border.color: Config.ThemeConfig.colors.primary; border.width: 1
                        height: 14; width: procNodes.implicitWidth + 10
                        Text { id: procNodes; anchors.centerIn: parent; text: Services.GpuService.processes.length + " ACTIVE"
                            color: Config.ThemeConfig.colors.primary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 7; font.bold: true } }
                }

                // empty state
                Text { visible: Services.GpuService.processes.length === 0
                    Layout.fillWidth: true; Layout.fillHeight: true
                    text: "NO ACTIVE GPU PROCESSES"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }

                Repeater {
                    model: Services.GpuService.processes
                    delegate: Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 32
                        color: Qt.rgba(0, 0, 0, 0.4); border.color: Config.ThemeConfig.colors.border; border.width: 1
                        ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 3
                            RowLayout { Layout.fillWidth: true; spacing: 6
                                Text { text: (index + 1).toString().padStart(2, "0"); color: Config.ThemeConfig.colors.primary
                                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
                                Text { text: modelData.name; color: Config.ThemeConfig.colors.text
                                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; elide: Text.ElideRight; Layout.fillWidth: true }
                                Text { text: modelData.memMiB.toFixed(0) + " MiB"; color: Config.ThemeConfig.colors.secondary
                                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
                            }
                            CoreBar { Layout.fillWidth: true; barHeight: 2
                                value: modelData.memMiB / root.procMaxMem * 100; barColor: Config.ThemeConfig.colors.secondary }
                        }
                    }
                }
            }
        }
    }

    // ── 3. STATUS FOOTER ────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true; spacing: 8

        Rectangle {        // VENDOR
            height: 22; width: venRow.implicitWidth + 16
            color: Qt.rgba(1, 1, 1, 0.03); border.color: Config.ThemeConfig.colors.border; border.width: 1
            RowLayout { id: venRow; anchors.centerIn: parent; spacing: 6
                Rectangle { width: 6; height: 6; radius: 3; color: Config.ThemeConfig.colors.secondary }
                Text { text: "VENDOR"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                Text { text: Services.GpuService.vendor.toUpperCase(); color: Config.ThemeConfig.colors.secondary
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
            }
        }
        Rectangle {        // DEVICE
            height: 22; width: drvRow.implicitWidth + 16
            color: Qt.rgba(1, 1, 1, 0.03); border.color: Config.ThemeConfig.colors.border; border.width: 1
            RowLayout { id: drvRow; anchors.centerIn: parent; spacing: 6
                Rectangle { width: 6; height: 6; radius: 3; color: Services.GpuService.present ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.error }
                Text { text: "DEVICE"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                Text { text: Services.GpuService.present ? "ONLINE" : "OFFLINE"
                    color: Services.GpuService.present ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.error
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
            }
        }
        Rectangle {        // FAN
            height: 22; width: fanRow.implicitWidth + 16
            color: Qt.rgba(1, 1, 1, 0.03); border.color: Config.ThemeConfig.colors.border; border.width: 1
            RowLayout { id: fanRow; anchors.centerIn: parent; spacing: 6
                Rectangle { width: 6; height: 6; radius: 3; color: Config.ThemeConfig.colors.secondary }
                Text { text: "FAN"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                Text { text: Services.GpuService.fanPct.toFixed(0) + "%"; color: Config.ThemeConfig.colors.text
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
            }
        }

        Item { Layout.fillWidth: true }
        Text { text: "REFRESH 2.0s"; color: Config.ThemeConfig.colors.textDim
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.letterSpacing: 1 }
    }
}
