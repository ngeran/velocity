// CoreLcdPane.qml — physical AIO LCD control (Core tab; Shibumi viewport-fit)
// 2-column layout: DISPLAY + LCD SLOTS on the left, live rotating LCD preview
// on the right. Persists to ~/.config/quickshell/deepcool-config.json (read
// live by deepcool-py --sink). Fixed composition — no scrolling (§6.1).

import QtQuick
import QtQuick.Layouts
import Qt.labs.platform
import Quickshell.Io
import "../config" as Config
import "../services" as Services

ColumnLayout {
    id: root
    spacing: Config.ControlConfig.space3

    property bool lcdEnabled: true
    property string mode: "cpu"
    property int rotation: 180
    property string unit: "C"
    property string mainTempSource: "cpu_temp"
    property string gpuTempSource: "gpu_temp"
    property string usageSource: "cpu_usage"
    property string ramSource: "ram_pct"
    property string freqSource: "cpu_ghz"

    readonly property string cfgPath: StandardPaths.writableLocation(StandardPaths.ConfigLocation)
                                      .toString().replace("file://", "") + "/quickshell/deepcool-config.json"

    property Process saveProc: Process { command: []; running: false }
    property Process loadProc: Process {
        command: []; running: false
        property string buffer: ""
        stdout: SplitParser { onRead: function(d) { loadProc.buffer += d } }
        onRunningChanged: {
            if (!running && loadProc.buffer.length) {
                try {
                    var d = JSON.parse(loadProc.buffer)
                    root.lcdEnabled = (d.enabled !== false)
                    root.mode = d.mode || "cpu"; root.rotation = d.rotation || 0; root.unit = d.unit || "C"
                    var s = d.slots || {}
                    root.mainTempSource = s.cpu_temp || "cpu_temp"; root.gpuTempSource = s.gpu_temp || "gpu_temp"
                    root.usageSource = s.usage || "cpu_usage"; root.ramSource = s.ram || "ram_pct"; root.freqSource = s.freq || "cpu_ghz"
                } catch (e) {}
                loadProc.buffer = ""
            }
        }
    }
    Component.onCompleted: { loadProc.command = ["cat", root.cfgPath]; loadProc.running = true }

    function save() {
        var cfg = { enabled: root.lcdEnabled, mode: root.mode, rotation: root.rotation, unit: root.unit,
            slots: { cpu_temp: root.mainTempSource, gpu_temp: root.gpuTempSource, usage: root.usageSource, ram: root.ramSource, freq: root.freqSource },
            sources: { coolant: true, nvme: true } }
        var json = JSON.stringify(cfg, null, 2)
        saveProc.command = ["sh", "-c", "printf '%s' '" + json.replace(/'/g, "'\\''") + "' > '" + root.cfgPath + "'"]
        saveProc.running = true
    }

    function tempStr(celsius) { var v = root.unit === "F" ? celsius * 9.0 / 5.0 + 32.0 : celsius; return Math.round(v) + "°" }
    function metricValue(key) {
        switch (key) {
            case "cpu_temp": return tempStr(Services.ThermalService.cpuTemp)
            case "gpu_temp": return tempStr(Services.GpuService.temp)
            case "coolant_temp": return Services.ThermalService.coolantAvailable ? tempStr(Services.ThermalService.coolantTemp) : "N/A"
            case "nvme_temp": return Services.ThermalService.nvmeTemp > 0 ? tempStr(Services.ThermalService.nvmeTemp) : "N/A"
            case "cpu_usage": return Math.round(Services.CoreEngineService.cpuUsage) + "%"
            case "gpu_usage": return Math.round(Services.GpuService.util) + "%"
            case "ram_pct": return Math.round(Services.CoreEngineService.ramPct) + "%"
            case "swap_pct": return Math.round(Services.CoreEngineService.swapPct) + "%"
            case "disk_pct": return Math.round(Services.CoreEngineService.diskPct) + "%"
            case "cpu_ghz": return Services.CoreEngineService.cpuGhz.toFixed(2)
        }
        return "—"
    }

    // Local segment button (ControlSeg idiom, self-contained so picked()
    // carries the persist call with the NEW value).
    component LcdSeg: Rectangle {
        property string text: ""
        property bool sel: false
        signal picked()
        height: 24; width: segLbl.implicitWidth + 16
        radius: Config.ControlConfig.radiusPill
        color: sel ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.16)
               : (segMA.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.text, 0.06)
                                      : Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.4))
        border.color: sel ? Config.ControlConfig.accent : Config.ThemeConfig.colors.outlineVariant
        border.width: 1
        Behavior on color { ColorAnimation { duration: 100 } }
        Text { id: segLbl; anchors.centerIn: parent; text: parent.text
            color: sel ? Config.ControlConfig.accent : Config.ThemeConfig.colors.text
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
        MouseArea { id: segMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: if (!sel) picked() }
    }

    // ── header ──────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Text { text: "LCD CONTROL"; color: Config.ThemeConfig.colors.textDim
            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
        Item { Layout.fillWidth: true }
        Text { text: root.cfgPath; color: Config.ThemeConfig.colors.textDim; opacity: 0.7
            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; elide: Text.ElideMiddle }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Config.ControlConfig.space3

        // ── LEFT: DISPLAY + SLOTS ──────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Config.ControlConfig.space3

            CoreCard {
                contentSpacing: Config.ControlConfig.space2
                accent: Config.ThemeConfig.colors.warning
                Layout.fillWidth: true
                Text { text: "DISPLAY"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                RowLayout { Layout.fillWidth: true; spacing: 12
                    Text { text: "ENABLED"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontSans
                        font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; Layout.preferredWidth: 80 }
                    Item { Layout.fillWidth: true }
                    PowerPill {
                        on: root.lcdEnabled
                        onClicked: { root.lcdEnabled = !root.lcdEnabled; root.save() }
                    }
                }
                RowLayout { Layout.fillWidth: true; spacing: 6
                    Text { text: "MODE"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontSans
                        font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; Layout.preferredWidth: 80 }
                    Item { Layout.fillWidth: true }
                    LcdSeg { text: "CPU"; sel: root.mode === "cpu"; onPicked: { root.mode = "cpu"; root.save() } }
                    LcdSeg { text: "GPU"; sel: root.mode === "gpu"; onPicked: { root.mode = "gpu"; root.save() } }
                    LcdSeg { text: "GFOCUS"; sel: root.mode === "gpu_focus"; onPicked: { root.mode = "gpu_focus"; root.save() } }
                }
                RowLayout { Layout.fillWidth: true; spacing: 6
                    Text { text: "ROTATION"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontSans
                        font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; Layout.preferredWidth: 80 }
                    Item { Layout.fillWidth: true }
                    LcdSeg { text: "0°"; sel: root.rotation === 0; onPicked: { root.rotation = 0; root.save() } }
                    LcdSeg { text: "90°"; sel: root.rotation === 90; onPicked: { root.rotation = 90; root.save() } }
                    LcdSeg { text: "180°"; sel: root.rotation === 180; onPicked: { root.rotation = 180; root.save() } }
                    LcdSeg { text: "270°"; sel: root.rotation === 270; onPicked: { root.rotation = 270; root.save() } }
                }
                RowLayout { Layout.fillWidth: true; spacing: 6
                    Text { text: "UNIT"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontSans
                        font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; Layout.preferredWidth: 80 }
                    Item { Layout.fillWidth: true }
                    LcdSeg { text: "°C"; sel: root.unit === "C"; onPicked: { root.unit = "C"; root.save() } }
                    LcdSeg { text: "°F"; sel: root.unit === "F"; onPicked: { root.unit = "F"; root.save() } }
                }
            }

            CoreCard {
                contentSpacing: Config.ControlConfig.space2
                accent: Config.ThemeConfig.colors.warning
                Layout.fillWidth: true
                Layout.fillHeight: true
                Text { text: "LCD SLOTS"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                RowLayout { Layout.fillWidth: true; spacing: 6
                    Text { text: "MAIN TEMP"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontSans
                        font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; Layout.preferredWidth: 80 }
                    Text { text: root.metricValue(root.mainTempSource); color: Config.ControlConfig.accent
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                    Item { Layout.fillWidth: true }
                    LcdSeg { text: "CPU"; sel: root.mainTempSource === "cpu_temp"; onPicked: { root.mainTempSource = "cpu_temp"; root.save() } }
                    LcdSeg { text: "GPU"; sel: root.mainTempSource === "gpu_temp"; onPicked: { root.mainTempSource = "gpu_temp"; root.save() } }
                    LcdSeg { text: "COOL"; sel: root.mainTempSource === "coolant_temp"; onPicked: { root.mainTempSource = "coolant_temp"; root.save() } }
                    LcdSeg { text: "NVME"; sel: root.mainTempSource === "nvme_temp"; onPicked: { root.mainTempSource = "nvme_temp"; root.save() } }
                }
                RowLayout { Layout.fillWidth: true; spacing: 6
                    Text { text: "GPU TEMP"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontSans
                        font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; Layout.preferredWidth: 80 }
                    Text { text: root.metricValue(root.gpuTempSource); color: Config.ControlConfig.accent
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                    Item { Layout.fillWidth: true }
                    LcdSeg { text: "GPU"; sel: root.gpuTempSource === "gpu_temp"; onPicked: { root.gpuTempSource = "gpu_temp"; root.save() } }
                    LcdSeg { text: "CPU"; sel: root.gpuTempSource === "cpu_temp"; onPicked: { root.gpuTempSource = "cpu_temp"; root.save() } }
                    LcdSeg { text: "NVME"; sel: root.gpuTempSource === "nvme_temp"; onPicked: { root.gpuTempSource = "nvme_temp"; root.save() } }
                }
                RowLayout { Layout.fillWidth: true; spacing: 6
                    Text { text: "USAGE"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontSans
                        font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; Layout.preferredWidth: 80 }
                    Text { text: root.metricValue(root.usageSource); color: Config.ControlConfig.accent
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                    Item { Layout.fillWidth: true }
                    LcdSeg { text: "CPU"; sel: root.usageSource === "cpu_usage"; onPicked: { root.usageSource = "cpu_usage"; root.save() } }
                    LcdSeg { text: "GPU"; sel: root.usageSource === "gpu_usage"; onPicked: { root.usageSource = "gpu_usage"; root.save() } }
                }
                RowLayout { Layout.fillWidth: true; spacing: 6
                    Text { text: "RAM SLOT"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontSans
                        font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; Layout.preferredWidth: 80 }
                    Text { text: root.metricValue(root.ramSource); color: Config.ControlConfig.accent
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                    Item { Layout.fillWidth: true }
                    LcdSeg { text: "RAM"; sel: root.ramSource === "ram_pct"; onPicked: { root.ramSource = "ram_pct"; root.save() } }
                    LcdSeg { text: "SWAP"; sel: root.ramSource === "swap_pct"; onPicked: { root.ramSource = "swap_pct"; root.save() } }
                    LcdSeg { text: "DISK"; sel: root.ramSource === "disk_pct"; onPicked: { root.ramSource = "disk_pct"; root.save() } }
                }
                RowLayout { Layout.fillWidth: true; spacing: 6
                    Text { text: "FREQ"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontSans
                        font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; Layout.preferredWidth: 80 }
                    Text { text: root.metricValue("cpu_ghz") + " GHz"; color: Config.ControlConfig.accent
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: "FIXED"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10 }
                }
                Item { Layout.fillHeight: true }
            }
        }

        // ── RIGHT: live rotating LCD preview ───────────────────────────
        CoreCard {
            accent: Config.ThemeConfig.colors.primary
            Layout.preferredWidth: 226
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            ColumnLayout { Layout.fillWidth: true; spacing: Config.ControlConfig.space2
                RowLayout { Layout.fillWidth: true; spacing: 8
                    Text { text: "󰍛"; font.family: Config.ControlConfig.fontNerd; font.pixelSize: 18
                        color: Config.ThemeConfig.colors.primary }
                    ColumnLayout { spacing: 1
                        Text { text: "LCD PREVIEW"; color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                        Text { text: root.lcdEnabled ? ("ROT " + root.rotation + "°  •  °" + root.unit) : "DISABLED"
                            color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
                    }
                }
                // Device mock: the bezel/screen use the theme background (and a
                // Qt.lighter derivation for the glass) — a physical LCD is black
                // by nature, but the values stay theme-resolved (DESIGN_TOKENS
                // rule 1: derivations, never new hex).
                Item { id: previewWrap; Layout.fillWidth: true; Layout.preferredHeight: previewWrap.width; Layout.alignment: Qt.AlignHCenter
                    Rectangle { anchors.fill: parent; radius: 16; color: Config.ThemeConfig.colors.background
                        border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
                        Rectangle { anchors.fill: parent; anchors.margins: 11; radius: 12
                            color: Qt.lighter(Config.ThemeConfig.colors.background, 1.15); clip: true; rotation: root.rotation
                            ColumnLayout { anchors.fill: parent; anchors.margins: 14; spacing: 8
                                RowLayout { Layout.fillWidth: true
                                    Item { Layout.fillWidth: true }
                                    Text { text: root.metricValue(root.mainTempSource); color: Config.ThemeConfig.colors.primary
                                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 34; font.bold: true }
                                    Item { Layout.fillWidth: true }
                                }
                                RowLayout { Layout.fillWidth: true; spacing: 6
                                    Text { text: root.metricValue(root.gpuTempSource); color: Config.ControlConfig.accent
                                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 15; font.bold: true }
                                    Item { Layout.fillWidth: true }
                                    Text { text: root.metricValue(root.usageSource); color: Config.ControlConfig.accent
                                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 15; font.bold: true }
                                }
                                RowLayout { Layout.fillWidth: true; spacing: 6
                                    Text { text: root.metricValue(root.ramSource); color: Config.ThemeConfig.colors.warning
                                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 15; font.bold: true }
                                    Item { Layout.fillWidth: true }
                                    Text { text: root.metricValue("cpu_ghz"); color: Config.ThemeConfig.colors.warning
                                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 15; font.bold: true }
                                }
                            }
                        }
                    }
                }
                Text { text: "Changes apply live"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                    Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
            }
        }
    }
}
