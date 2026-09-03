// =============================================================================
// CoreGpuSection.qml — GPU pane (Core tab; bold Shibumi: hero rings)
// =============================================================================
// Mirrors CoreCpuSection's bold composition (§6.1 — no scrolling):
//   1. HERO ROW      — three instrumentation rings (GPU / TEMP / VRAM)
//   2. BODY          — GPU PROCESSES (visibility-clamped) | UTIL FLOW + SPEC
// All data from Services.GpuService (vendor-aware; nvidia-smi today). Tier
// ramps delegate to ThemeConfig.tierColor; fills are tint tokens.
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
    function loadTier(v) { return Config.ThemeConfig.tierColor(v, 50, 85) }
    function vramTier(v) { return Config.ThemeConfig.tierColor(v, 70, 90) }

    // processes[] is sorted desc by memMiB in GpuService → [0] is the max.
    readonly property real procMaxMem: (Services.GpuService.processes.length > 0
        ? Services.GpuService.processes[0].memMiB : 1) || 1
    // Visibility clamp (§6.1): rows hide beyond capacity — NEVER slice the
    // model (fresh arrays destroy delegates mid-interaction; see SKILL §6.1).
    readonly property int procCapacity: Math.max(1, Math.floor(procViewport.height / 34))
    readonly property int procVisibleCount: Math.min(Services.GpuService.processes.length, procCapacity)

    // ── 1. HERO ROW — three big-numeral stat blocks (palette-mapped:
    // GPU=info violet · TEMP=temp tier · VRAM=primary teal) ──────────────
    component StatBlock: Rectangle {
        property string label: ""
        property string value: "—"
        property string unit: ""
        property color valueColor: Config.ThemeConfig.colors.text
        property real meterValue: -1        // <0 hides the meter
        property color meterColor: Config.ThemeConfig.colors.info
        Layout.fillWidth: true; Layout.preferredHeight: 92
        radius: Config.ControlConfig.radiusPill
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
        border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
        ColumnLayout { anchors.fill: parent; anchors.margins: 12; spacing: 4
            Text { text: label; color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                font.bold: true; font.letterSpacing: 1.0 }
            RowLayout { spacing: 4
                Text { text: value; color: valueColor
                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 34; font.bold: true }
                Text { visible: unit !== ""; text: unit; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 12 }
                Item { Layout.fillWidth: true }
            }
            CoreBar { Layout.fillWidth: true; barHeight: 4; visible: meterValue >= 0
                value: meterValue; barColor: meterColor }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Config.ControlConfig.space3

        StatBlock { label: "GPU UTILIZATION"
            value: Math.round(Services.GpuService.util); unit: "%"
            valueColor: Config.ThemeConfig.colors.info
            meterValue: Services.GpuService.util
            meterColor: Config.ThemeConfig.colors.info }
        StatBlock { label: "GPU TEMP"
            value: Services.GpuService.temp.toFixed(0); unit: "°C"
            valueColor: root.tempTier(Services.GpuService.temp)
            meterValue: Services.GpuService.temp
            meterColor: root.tempTier(Services.GpuService.temp) }
        StatBlock { label: "VRAM"
            value: Math.round(Services.GpuService.vramPct); unit: "%"
            valueColor: Config.ThemeConfig.colors.primary
            meterValue: Services.GpuService.vramPct
            meterColor: Config.ThemeConfig.colors.primary }
    }

    // ── 1b. UTIL FLOW — compact full-width strip, auto-scaled ───────────
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 72
        radius: Config.ControlConfig.radiusPill
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
        border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 8; spacing: 4

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text { text: "UTIL FLOW"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                Item { Layout.fillWidth: true }
                Text { text: Math.round(Services.GpuService.util) + "% NOW"
                    color: Config.ThemeConfig.colors.info
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                Text { text: "2 MIN"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.letterSpacing: 0.8 }
            }

            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                CoreSparkline { anchors.fill: parent
                    points: Services.GpuService.gpuHistory
                    lineColor: Config.ThemeConfig.colors.info }
            }
        }
    }

    // ── 2. BODY — processes (left) | util flow + spec (right) ───────────
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Config.ControlConfig.space3

        // LEFT — top GPU processes (nvtop-equivalent), visibility-clamped
        CoreCard {
            accent: Config.ThemeConfig.colors.primary
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: Config.ControlConfig.space2

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "GPU PROCESSES"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                    Item { Layout.fillWidth: true }
                    Text { text: "REFRESH 2.0s"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.letterSpacing: 0.8 }
                    Rectangle { radius: Config.ControlConfig.radiusSmall
                        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.primary, 0.12)
                        border.color: Config.ThemeConfig.colors.primary; border.width: 1
                        height: 18; width: procNodes.implicitWidth + 12
                        Text { id: procNodes; anchors.centerIn: parent
                            text: Services.GpuService.processes.length > 0
                                  ? (root.procVisibleCount + " / " + Services.GpuService.processes.length) : "0"
                            color: Config.ThemeConfig.colors.primary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true } }
                }

                Item {
                    id: procViewport
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 4
                        Repeater {
                            model: Services.GpuService.processes
                            delegate: Rectangle {
                                width: parent.width
                                visible: index < root.procCapacity
                                height: 30
                                radius: Config.ControlConfig.radiusSmall
                                color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
                                border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
                                ColumnLayout { anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 3
                                    RowLayout { Layout.fillWidth: true; spacing: 6
                                        Text { text: (index + 1).toString().padStart(2, "0"); color: Config.ThemeConfig.colors.primary
                                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                                        Text { text: modelData.name; color: Config.ThemeConfig.colors.text
                                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                                        Text { text: modelData.memMiB.toFixed(0) + " MiB"; color: Config.ControlConfig.accent
                                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                                    }
                                    CoreBar { Layout.fillWidth: true; barHeight: 2
                                        value: modelData.memMiB / root.procMaxMem * 100; barColor: Config.ControlConfig.accent }
                                }
                            }
                        }
                    }

                    // empty state
                    Text { visible: Services.GpuService.processes.length === 0
                        anchors.centerIn: parent
                        text: "NO ACTIVE GPU PROCESSES"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.procVisibleCount < Services.GpuService.processes.length
                    text: "+ " + (Services.GpuService.processes.length - root.procVisibleCount) + " more hidden"
                    color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }

        // RIGHT — spec rows (util flow lives in the compact strip above)
        ColumnLayout {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            spacing: Config.ControlConfig.space3

            // SPEC — the numbers the hero blocks don't show
            CoreCard {
                accent: Config.ThemeConfig.colors.secondary
                Layout.fillWidth: true
                Layout.fillHeight: true
                ColumnLayout {
                    Layout.fillWidth: true; spacing: Config.ControlConfig.space2
                    Text { text: "SPEC"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                    InfoStatRow { label: "Device"
                        value: Services.GpuService.present ? (Services.GpuService.name || "GPU") : "NO GPU" }
                    InfoStatRow { label: "VRAM"
                        value: Services.GpuService.vramUsedGB.toFixed(1) + " / " + Services.GpuService.vramTotalGB.toFixed(0) + " GB"
                        accentValue: true }
                    InfoStatRow { label: "Clock"; value: Services.GpuService.clockMHz.toFixed(0) + " MHz" }
                    InfoStatRow { label: "Power"; value: Services.GpuService.powerW.toFixed(0) + " W" }
                    InfoStatRow { label: "Fan"; value: Services.GpuService.fanPct.toFixed(0) + "%" }
                    InfoStatRow { label: "Vendor"; value: Services.GpuService.vendor.toUpperCase() }
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
