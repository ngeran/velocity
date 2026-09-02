// =============================================================================
// CoreGpuSection.qml — GPU pane (Core tab; Shibumi viewport-fit)
// =============================================================================
// Mirrors CoreCpuSection's fixed composition (§6.1 — no scrolling):
//   1. SPEC STRIP     — device / VRAM / temp / power accent-ticked tiles
//   2. MAIN SPLIT     — util ring + util-flow sparkline + metric tiles |
//                        top GPU processes (visibility-clamped, honest counts)
//   3. STATUS FOOTER  — vendor / device / fan chips + refresh cadence
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

    // ── 1. SPEC STRIP ───────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true; spacing: Config.ControlConfig.space2

        component SpecTile: Rectangle {
            property string label: ""
            property string value: "—"
            property color tick: Config.ControlConfig.accent
            property color valueColor: Config.ThemeConfig.colors.text
            Layout.fillWidth: true; Layout.preferredHeight: 46
            radius: Config.ControlConfig.radiusPill
            color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
            border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
            Rectangle { anchors.left: parent.left; anchors.leftMargin: 6
                anchors.top: parent.top; anchors.topMargin: 8
                anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                width: 3; radius: 1.5; color: tick }
            ColumnLayout { anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 8
                anchors.topMargin: 7; anchors.bottomMargin: 7; spacing: 0
                Text { text: label; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                Text { text: value; color: valueColor; elide: Text.ElideRight
                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 15; font.bold: true }
            }
        }

        SpecTile { label: "Device"; value: Services.GpuService.present ? (Services.GpuService.name || "GPU") : "NO GPU" }
        SpecTile { label: "VRAM"; value: Services.GpuService.vramUsedGB.toFixed(1) + "/" + Services.GpuService.vramTotalGB.toFixed(0) + "G"
            tick: root.vramTier(Services.GpuService.vramPct); valueColor: root.vramTier(Services.GpuService.vramPct) }
        SpecTile { label: "Temp"; value: Math.round(Services.GpuService.temp) + " °C"
            tick: root.tempTier(Services.GpuService.temp); valueColor: root.tempTier(Services.GpuService.temp) }
        SpecTile { label: "Power"; value: Services.GpuService.powerW.toFixed(0) + " W" }
    }

    // ── 2. MAIN SPLIT: ring+sparkline+metrics (left) | processes (right) ─
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Config.ControlConfig.space3

        // LEFT — utilization ring + history sparkline + 2×2 metric tiles
        CoreCard {
            accent: Config.ControlConfig.accent
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: Config.ControlConfig.space2

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "GPU LOAD"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                    Item { Layout.fillWidth: true }
                    Rectangle { width: 7; height: 7; radius: 4; color: Config.ThemeConfig.colors.success
                        SequentialAnimation on opacity { loops: Animation.Infinite; running: Config.SharedState.dashboardVisible
                            NumberAnimation { to: 0.3; duration: 700 } NumberAnimation { to: 1; duration: 700 } } }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    HudGauge {
                        value: Services.GpuService.util; max: 100; size: 118
                        accent: root.loadTier(Services.GpuService.util)
                        label: "UTILIZATION"; unit: "%"
                    }
                    Item { Layout.fillWidth: true }
                }

                // utilization history — service-owned 2-min ring buffer
                // (GpuService.gpuHistory). Line stays warning-token so it
                // reads as a distinct series next to CPU (accent)/RAM (primary).
                ColumnLayout { Layout.fillWidth: true; spacing: 4
                    RowLayout { Layout.fillWidth: true
                        Text { text: "UTIL FLOW"; color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                        Item { Layout.fillWidth: true }
                        Text { text: "2 MIN"; color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.letterSpacing: 0.8 }
                    }
                    CoreSparkline { Layout.fillWidth: true; Layout.preferredHeight: 40
                        points: Services.GpuService.gpuHistory
                        lineColor: Config.ThemeConfig.colors.warning
                        fixedMaximum: 100 }
                }

                component MetricTile: Rectangle {
                    property string label: ""
                    property string value: "—"
                    property string unit: ""
                    property color valueColor: Config.ThemeConfig.colors.text
                    property real meterValue: -1        // <0 hides the meter
                    property color meterColor: Config.ControlConfig.accent
                    Layout.fillWidth: true; Layout.preferredHeight: 52
                    radius: Config.ControlConfig.radiusPill
                    color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
                    border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
                    ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 3
                        Text { text: label; color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8 }
                        RowLayout { spacing: 2
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

                GridLayout {
                    Layout.fillWidth: true; columns: 2; rowSpacing: Config.ControlConfig.space2; columnSpacing: Config.ControlConfig.space2

                    MetricTile { label: "CORE TEMP"; value: Services.GpuService.temp.toFixed(0); unit: "°C"
                        valueColor: root.tempTier(Services.GpuService.temp)
                        meterValue: Services.GpuService.temp; meterColor: root.tempTier(Services.GpuService.temp) }
                    MetricTile { label: "VRAM"; value: Math.round(Services.GpuService.vramPct); unit: "%"
                        valueColor: root.vramTier(Services.GpuService.vramPct)
                        meterValue: Services.GpuService.vramPct; meterColor: root.vramTier(Services.GpuService.vramPct) }
                    MetricTile { label: "CLOCK"; value: Services.GpuService.clockMHz.toFixed(0); unit: "MHz"
                        valueColor: Config.ControlConfig.accent }
                    MetricTile { label: "POWER"; value: Services.GpuService.powerW.toFixed(0); unit: "W" }
                }
            }
        }

        // RIGHT — top GPU processes (nvtop-equivalent), visibility-clamped
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
    }

    // ── 3. STATUS FOOTER ────────────────────────────────────────────────
    component StatusChip: Rectangle {
        property color tick: Config.ControlConfig.accent
        property string label: ""
        property string value: ""
        height: 22; width: chipRow.implicitWidth + 16
        radius: Config.ControlConfig.radiusPill
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.4)
        border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
        RowLayout { id: chipRow; anchors.centerIn: parent; spacing: 6
            Rectangle { width: 6; height: 6; radius: 3; color: tick }
            Text { text: label; color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8 }
            Text { text: value; color: tick
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
        }
    }

    RowLayout {
        Layout.fillWidth: true; spacing: Config.ControlConfig.space2

        StatusChip { label: "VENDOR"; value: Services.GpuService.vendor.toUpperCase() }
        StatusChip { label: "DEVICE"; value: Services.GpuService.present ? "ONLINE" : "OFFLINE"
            tick: Services.GpuService.present ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.error }
        StatusChip { label: "FAN"; value: Services.GpuService.fanPct.toFixed(0) + "%" }

        Item { Layout.fillWidth: true }
        Text { text: "REFRESH 2.0s"; color: Config.ThemeConfig.colors.textDim
            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.letterSpacing: 0.8 }
    }
}
