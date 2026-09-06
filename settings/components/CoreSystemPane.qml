// =============================================================================
// CoreSystemPane.qml — SYSTEM: digital instrument cluster
// =============================================================================
// systemricer-inspired: one continuous bordered panel with hairline dividers
// (not floating cards). Layout, top to bottom:
//   header rail   SYSTEM / TELEMETRY · DIGITAL INSTRUMENT CLUSTER · ● LIVE
//   load band     LED-matrix CPU history, 0–100 scale
//   main row      GPU dial readout | dominant PROCESSOR digits | MEMORY banks
//   aux row       CPU TEMP ticks · PER-CORE LEDs · STORAGE · ENGINE
//   footer rail   LOCAL TELEMETRY / sample · UPDATED Ns AGO
// Every colour is a ThemeConfig token, so the cluster retints with the active
// scheme. All instruments keep fixed locations — a missing sensor renders an
// em dash and never shifts its neighbours.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Rectangle {
    id: root
    radius: Config.ControlConfig.radiusPill
    color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.55)
    border.color: Config.ThemeConfig.colors.outlineVariant
    border.width: 1
    clip: true

    readonly property int coreCount: Math.max(1, Services.CoreEngineService.perCoreLoad.length)
    function tempTier(t) { return Config.ThemeConfig.tierColor(t, 55, 75) }
    function loadTier(v) { return Config.ThemeConfig.tierColor(v, 50, 85) }
    function diskTier(p) { return Config.ThemeConfig.tierColor(p, 70, 85) }
    // Hoisted to a property (not an inline-literal model): Repeater delegates
    // over literal arrays have hit the singleton-not-ready init trap before.
    readonly property var engineRows: [
        { k: "COOLANT", v: Services.ThermalService.coolantAvailable ? Services.ThermalService.coolantTemp.toFixed(0) + "°C" : "—",
          c: Services.ThermalService.coolantAvailable ? tempTier(Services.ThermalService.coolantTemp) : Config.ThemeConfig.colors.textDim },
        { k: "NVME", v: Services.ThermalService.nvmeTemp > 0 ? Services.ThermalService.nvmeTemp.toFixed(0) + "°C" : "—",
          c: Services.ThermalService.nvmeTemp > 0 ? tempTier(Services.ThermalService.nvmeTemp) : Config.ThemeConfig.colors.textDim },
        { k: "CLOCK", v: Services.GpuService.clockMHz > 0 ? (Services.GpuService.clockMHz / 1000).toFixed(2) + " GHz" : "—",
          c: Config.ThemeConfig.colors.info },
        { k: "PROCS", v: "" + Services.GpuService.processes.length, c: Config.ThemeConfig.colors.text }
    ]
    function driveLabel(mount) {
        return mount === "/" ? "SYSTEM" : (mount.split("/").pop() || mount)
    }

    // "UPDATED Ns AGO" — resets whenever live telemetry ticks
    readonly property string _sig: Services.CoreEngineService.cpuUsage.toFixed(3)
    property int _agoSec: 0
    on_SigChanged: _agoSec = 0
    Timer { interval: 1000; repeat: true; running: root.visible; onTriggered: root._agoSec++ }

    // Uptime string is pull-based — refresh on every pane entry so the
    // trip-computer line never shows a stale/em-dash value.
    onVisibleChanged: if (visible) Services.SysInfoService.refreshUptime()

    component DashLabel: Text {
        color: Config.ThemeConfig.colors.textDim
        font.family: Config.ControlConfig.fontSans
        font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.4
    }
    component DashValue: Text {
        color: Config.ThemeConfig.colors.text
        font.family: Config.SettingsConfig.fontFamily
        font.pixelSize: 13; font.bold: true
    }
    component DashDivider: Rectangle { color: Config.ThemeConfig.colors.outlineVariant; opacity: 0.55 }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ═══════════════════════════════════════════════════════════════════
        // HEADER RAIL — identity · cluster title · live status
        // ═══════════════════════════════════════════════════════════════════
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            DashLabel { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: "SYSTEM / TELEMETRY"; font.pixelSize: 11 }
            DashLabel { anchors.centerIn: parent
                text: "DIGITAL INSTRUMENT CLUSTER"; font.bold: false; font.letterSpacing: 2.2 }
            RowLayout { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                Rectangle { width: 6; height: 6; radius: 3; color: Config.ThemeConfig.colors.success }
                Text { text: "LIVE"; color: Config.ThemeConfig.colors.success
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.4 }
            }
        }
        DashDivider { Layout.fillWidth: true; height: 1 }

        // ═══════════════════════════════════════════════════════════════════
        // LOAD BAND — continuous CPU history across the full panel width
        // ═══════════════════════════════════════════════════════════════════
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            clip: true
            ColumnLayout { anchors.fill: parent; anchors.margins: 10; spacing: 4
                RowLayout { Layout.fillWidth: true
                    DashLabel { text: "CPU LOAD / %" }
                    Item { Layout.fillWidth: true }
                    Text { text: Services.CoreEngineService.cpuUsage.toFixed(1) + " %"
                        color: root.loadTier(Services.CoreEngineService.cpuUsage)
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                }
                CoreDashBand {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    points: Services.CoreEngineService.cpuHistory
                    columns: 64
                }
                RowLayout { Layout.fillWidth: true
                    Text { text: "0"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                    Item { Layout.fillWidth: true }
                    Text { text: "50"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                    Item { Layout.fillWidth: true }
                    Text { text: "100"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                }
            }
        }
        DashDivider { Layout.fillWidth: true; height: 1 }

        // ═══════════════════════════════════════════════════════════════════
        // MAIN ROW — GPU dial · dominant PROCESSOR digits · MEMORY banks
        // ═══════════════════════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 5
            spacing: 0

            // ── GPU: dial + supporting readout ────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.minimumWidth: 150
                spacing: 2
                Item { Layout.fillWidth: true; Layout.preferredHeight: 8 }
                DashLabel { Layout.leftMargin: 12; text: "GPU UTILIZATION" }
                RowLayout { Layout.leftMargin: 12; Layout.fillWidth: true; spacing: 2
                    Text { text: Services.GpuService.util > 0 ? Math.round(Services.GpuService.util) : "—"
                        color: Config.ThemeConfig.colors.text
                        font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 34; font.bold: true }
                    Text { text: "%"; color: Config.ThemeConfig.colors.info
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 13; font.bold: true }
                }
                Text { Layout.leftMargin: 12; text: Services.GpuService.temp > 0
                        ? Math.round(Services.GpuService.temp) + " °C / " + Services.GpuService.vramUsedGB.toFixed(1) + " GB VRAM"
                        : "NO GPU SENSOR"
                    color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                CoreDashDial {
                    id: gpuDial
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Layout.margins: 4
                    value: Services.GpuService.util
                    accent: Config.ThemeConfig.colors.info
                }
                Text { Layout.leftMargin: 12; text: "FAN " + Services.GpuService.fanPct.toFixed(0) + "%"
                    color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                Item { Layout.fillWidth: true; Layout.preferredHeight: 8 }
            }
            DashDivider { Layout.fillHeight: true; width: 1 }

            // ── PROCESSOR: the dominant central instrument ─────────────────
            // Label pinned to the top rail (level with GPU/MEMORY labels);
            // digits centered in the space below — never collides sideways.
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.preferredWidth: 1.5
                spacing: 0
                Item { Layout.fillWidth: true; Layout.preferredHeight: 8 }
                DashLabel { Layout.alignment: Qt.AlignHCenter; text: "PROCESSOR" }
                Item { Layout.fillWidth: true; Layout.fillHeight: true }
                RowLayout { Layout.alignment: Qt.AlignHCenter; spacing: 4
                    Text { text: Services.CoreEngineService.cpuUsage > 0 ? Math.round(Services.CoreEngineService.cpuUsage) : "0"
                        color: Config.ThemeConfig.colors.text
                        font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 74; font.bold: true }
                    Text { text: "%"; color: Config.ThemeConfig.colors.primary
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 20; font.bold: true
                        Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 14 }
                }
                Text { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 2
                    text: Services.CoreEngineService.cpuGhz.toFixed(2) + " GHZ / CPU CLOCK"
                    color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                Text { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 4
                    text: "UPTIME " + Services.SysInfoService.uptime.toUpperCase()
                    color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
                Item { Layout.fillWidth: true; Layout.fillHeight: true }
            }
            DashDivider { Layout.fillHeight: true; width: 1 }

            // ── MEMORY: digits + dual-bank chip graphic ───────────────────
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.minimumWidth: 150
                spacing: 2
                Item { Layout.fillWidth: true; Layout.preferredHeight: 8 }
                DashLabel { Layout.leftMargin: 12; text: "MEMORY UTILIZATION" }
                RowLayout { Layout.leftMargin: 12; Layout.fillWidth: true; spacing: 2
                    Text { text: Math.round(Services.CoreEngineService.ramPct)
                        color: Config.ThemeConfig.colors.text
                        font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 34; font.bold: true }
                    Text { text: "%"; color: Config.ThemeConfig.colors.success
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 13; font.bold: true }
                }
                Text { Layout.leftMargin: 12
                    text: Services.CoreEngineService.ramUsedGB.toFixed(1) + " / " + Services.CoreEngineService.ramTotalGB.toFixed(1) + " GiB"
                    color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                Item { Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 8
                    Grid { id: bankGrid
                        anchors.centerIn: parent
                        columns: 12; rows: 2; spacing: 3
                        Repeater {
                            model: 24
                            Rectangle {
                                width: 13; height: 10; radius: 2
                                readonly property bool _lit: index < Math.round(Services.CoreEngineService.ramPct / 100 * 24)
                                color: _lit ? root.loadTier(Services.CoreEngineService.ramPct)
                                            : Config.ThemeConfig.tint(Config.ThemeConfig.colors.text, 0.08)
                                border.color: Config.ThemeConfig.colors.outlineVariant
                                border.width: _lit ? 0 : 1
                            }
                        }
                    }
                }
                Text { Layout.leftMargin: 12; text: "SWAP " + Services.CoreEngineService.swapUsedGB.toFixed(1) + " / " + Services.CoreEngineService.swapTotalGB.toFixed(0) + " GB"
                    color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                Item { Layout.fillWidth: true; Layout.preferredHeight: 8 }
            }
        }
        DashDivider { Layout.fillWidth: true; height: 1 }

        // ═══════════════════════════════════════════════════════════════════
        // AUX ROW — CPU TEMP · PER-CORE · STORAGE · ENGINE
        // ═══════════════════════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 3
            spacing: 0

            // ── CPU TEMP: segmented 0–110°C scale with 90° warning zone ───
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.minimumWidth: 120
                spacing: 3
                Item { Layout.fillWidth: true; Layout.preferredHeight: 6 }
                DashLabel { Layout.leftMargin: 12; text: "CPU TEMP" }
                RowLayout { Layout.leftMargin: 12; spacing: 2
                    Text { text: Services.ThermalService.cpuTemp > 0 ? Services.ThermalService.cpuTemp.toFixed(0) : "—"
                        color: Services.ThermalService.cpuTemp > 0 ? Config.ThemeConfig.colors.text : Config.ThemeConfig.colors.textDim
                        font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 24; font.bold: true }
                    Text { text: "°C"; color: root.tempTier(Services.ThermalService.cpuTemp)
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 11; font.bold: true }
                }
                Text { Layout.leftMargin: 12; text: "THERMAL / 0–110°C"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                Item { Layout.fillWidth: true; Layout.fillHeight: true
                    Row { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 12; spacing: 2
                        Repeater {
                            model: 22
                            Rectangle {
                                width: 4; height: 14; radius: 1
                                readonly property real _t: Services.ThermalService.cpuTemp
                                readonly property bool _lit: _t > 0 && index < Math.round(Math.min(110, _t) / 110 * 22)
                                color: !_lit ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.text, 0.08)
                                             : (index >= 18 ? Config.ThemeConfig.colors.error : root.tempTier(_t))
                            }
                        }
                    }
                }
                RowLayout { Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.fillWidth: true
                    Text { text: "0"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                    Item { Layout.fillWidth: true }
                    Text { text: "90⚠"; color: Config.ThemeConfig.colors.error
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                    Item { Layout.fillWidth: true }
                    Text { text: "110"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                }
                Item { Layout.fillWidth: true; Layout.preferredHeight: 6 }
            }
            DashDivider { Layout.fillHeight: true; width: 1 }

            // ── PER-CORE: LED heat grid ────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.minimumWidth: 110
                spacing: 3
                Item { Layout.fillWidth: true; Layout.preferredHeight: 6 }
                DashLabel { Layout.leftMargin: 12; text: "PER-CORE LOAD" }
                Text { Layout.leftMargin: 12; text: root.coreCount + " THREADS"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                Item { Layout.fillWidth: true; Layout.fillHeight: true
                    Grid {
                        anchors.centerIn: parent
                        columns: Math.ceil(root.coreCount / 2)
                        columnSpacing: 2; rowSpacing: 2
                        Repeater {
                            model: root.coreCount
                            Rectangle {
                                width: 9; height: 9; radius: 2
                                readonly property real _load: Services.CoreEngineService.perCoreLoad.length > index
                                                              ? Services.CoreEngineService.perCoreLoad[index] : 0
                                color: _load > 0 ? root.loadTier(_load)
                                                 : Config.ThemeConfig.tint(Config.ThemeConfig.colors.text, 0.08)
                                border.color: Config.ThemeConfig.colors.outlineVariant
                                border.width: _load > 0 ? 0 : 1
                            }
                        }
                    }
                }
                Item { Layout.fillWidth: true; Layout.preferredHeight: 6 }
            }
            DashDivider { Layout.fillHeight: true; width: 1 }

            // ── STORAGE: capacity blocks per real filesystem ───────────────
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.minimumWidth: 130
                spacing: 3
                Item { Layout.fillWidth: true; Layout.preferredHeight: 6 }
                DashLabel { Layout.leftMargin: 12; text: "STORAGE" }
                Text { Layout.leftMargin: 12; text: Services.CoreEngineService.disks.length + " FILESYSTEMS"
                    color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                Item { Layout.fillWidth: true; Layout.fillHeight: true
                    ColumnLayout { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                        anchors.topMargin: 2; anchors.bottomMargin: 4; spacing: 4
                        Repeater {
                            model: Services.CoreEngineService.disks
                            delegate: ColumnLayout {
                                id: dsk
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 2
                                RowLayout { Layout.fillWidth: true
                                    Text { text: root.driveLabel(dsk.modelData.mount)
                                        color: Config.ThemeConfig.colors.text
                                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
                                    Item { Layout.fillWidth: true }
                                    Text { text: Math.round(dsk.modelData.pct) + "%"
                                        color: root.diskTier(dsk.modelData.pct)
                                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                                }
                                Item { Layout.fillWidth: true; height: 8
                                    Row { anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                        Repeater {
                                            model: 12
                                            Rectangle {
                                                width: 8; height: 8; radius: 1
                                                readonly property bool _lit: index < Math.round(dsk.modelData.pct / 100 * 12)
                                                color: _lit ? root.diskTier(dsk.modelData.pct)
                                                            : Config.ThemeConfig.tint(Config.ThemeConfig.colors.text, 0.08)
                                                border.color: Config.ThemeConfig.colors.outlineVariant
                                                border.width: _lit ? 0 : 1
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Item { Layout.fillWidth: true; Layout.fillHeight: true }
                    }
                }
                Item { Layout.fillWidth: true; Layout.preferredHeight: 6 }
            }
            DashDivider { Layout.fillHeight: true; width: 1 }

            // ── ENGINE: board sensors + housekeeping ──────────────────────
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.minimumWidth: 120
                spacing: 3
                Item { Layout.fillWidth: true; Layout.preferredHeight: 6 }
                DashLabel { Layout.leftMargin: 12; text: "ENGINE" }
                Text { Layout.leftMargin: 12; text: Services.SysInfoService.hostname.toUpperCase()
                    color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; elide: Text.ElideRight
                    Layout.fillWidth: true; Layout.rightMargin: 12 }
                Item { Layout.fillWidth: true; Layout.fillHeight: true
                    ColumnLayout { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                        spacing: 3
                        Repeater {
                            model: root.engineRows
                            delegate: RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                Text { text: modelData.k; color: Config.ThemeConfig.colors.textDim
                                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                                Item { Layout.fillWidth: true }
                                Text { text: modelData.v; color: modelData.c
                                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 11; font.bold: true }
                            }
                        }
                    }
                }
                Item { Layout.fillWidth: true; Layout.preferredHeight: 6 }
            }
        }
        DashDivider { Layout.fillWidth: true; height: 1 }

        // ═══════════════════════════════════════════════════════════════════
        // FOOTER RAIL — telemetry provenance · freshness
        // ═══════════════════════════════════════════════════════════════════
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: "LOCAL TELEMETRY / 1S SAMPLE"
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.letterSpacing: 0.8 }
            Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: "UPDATED " + root._agoSec + "S AGO"
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.letterSpacing: 0.8 }
        }
    }
}
