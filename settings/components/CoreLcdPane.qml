// CoreLcdPane.qml — physical AIO LCD control, compact 2-column layout:
// DISPLAY + LCD SLOTS on the left (tightened), a live rotating LCD preview on
// the right. Persists to ~/.config/quickshell/deepcool-config.json (read live
// by deepcool-py --sink). Sized to fit the LCD page without scrolling.

import QtQuick
import QtQuick.Layouts
import Qt.labs.platform
import Quickshell.Io
import "../config" as Config
import "../services" as Services

Item {
    id: root
    Layout.fillWidth: true
    // Layouts read implicitHeight; height mirrors it for standalone use.
    implicitHeight: body.implicitHeight + 36
    height: implicitHeight

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

    ColumnLayout {
        id: body
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.leftMargin: 18; anchors.rightMargin: 18; anchors.topMargin: 18
        spacing: 12

        Text { text: "LCD CONTROL"; color: Config.ThemeConfig.colors.primary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 11; font.bold: true }
        Text { text: root.cfgPath; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }

        RowLayout {
            Layout.fillWidth: true; spacing: 12

            // ── LEFT: DISPLAY + SLOTS ──────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; spacing: 12

                CoreCard {
                    contentSpacing: 8; accent: Config.ThemeConfig.colors.warning; Layout.fillWidth: true
                    Text { text: "[ DISPLAY ]"; color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
                    RowLayout { Layout.fillWidth: true; spacing: 12
                        Text { text: "ENABLED"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.2; Layout.preferredWidth: 90 }
                        Item { Layout.fillWidth: true }
                        Rectangle { Layout.preferredWidth: 56; Layout.preferredHeight: 24
                            color: root.lcdEnabled ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
                            border.color: root.lcdEnabled ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border; border.width: 1
                            Text { anchors.centerIn: parent; text: root.lcdEnabled ? "ON" : "OFF"; color: root.lcdEnabled ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.text; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.lcdEnabled = !root.lcdEnabled; root.save() } }
                        }
                    }
                    RowLayout { Layout.fillWidth: true; spacing: 8
                        Text { text: "MODE"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.2; Layout.preferredWidth: 90 }
                        Item { Layout.fillWidth: true }
                        Repeater { model: [{l:"CPU",v:"cpu"},{l:"GPU",v:"gpu"},{l:"GFOCUS",v:"gpu_focus"}]
                            delegate: Rectangle { property bool sel: root.mode === modelData.v; Layout.preferredWidth: 56; Layout.preferredHeight: 24
                                color: sel ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
                                border.color: sel ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border; border.width: 1
                                Text { anchors.centerIn: parent; text: modelData.l; color: sel ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.text; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.mode = modelData.v; root.save() } } }
                        }
                    }
                    RowLayout { Layout.fillWidth: true; spacing: 8
                        Text { text: "ROTATION"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.2; Layout.preferredWidth: 90 }
                        Item { Layout.fillWidth: true }
                        Repeater { model: [{l:"0",v:0},{l:"90",v:90},{l:"180",v:180},{l:"270",v:270}]
                            delegate: Rectangle { property bool sel: root.rotation === modelData.v; Layout.preferredWidth: 46; Layout.preferredHeight: 24
                                color: sel ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
                                border.color: sel ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border; border.width: 1
                                Text { anchors.centerIn: parent; text: modelData.l + "°"; color: sel ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.text; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.rotation = modelData.v; root.save() } } }
                        }
                    }
                    RowLayout { Layout.fillWidth: true; spacing: 8
                        Text { text: "UNIT"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.2; Layout.preferredWidth: 90 }
                        Item { Layout.fillWidth: true }
                        Repeater { model: [{l:"C",v:"C"},{l:"F",v:"F"}]
                            delegate: Rectangle { property bool sel: root.unit === modelData.v; Layout.preferredWidth: 46; Layout.preferredHeight: 24
                                color: sel ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
                                border.color: sel ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border; border.width: 1
                                Text { anchors.centerIn: parent; text: "°" + modelData.l; color: sel ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.text; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.unit = modelData.v; root.save() } } }
                        }
                    }
                }

                CoreCard {
                    contentSpacing: 6; accent: Config.ThemeConfig.colors.warning; Layout.fillWidth: true
                    Text { text: "[ LCD SLOTS ]"; color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
                    RowLayout { Layout.fillWidth: true; spacing: 8
                        Text { text: "MAIN TEMP"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.0; Layout.preferredWidth: 80 }
                        Text { text: root.metricValue(root.mainTempSource); color: Config.ThemeConfig.colors.secondary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Repeater { model: [{l:"CPU",v:"cpu_temp"},{l:"GPU",v:"gpu_temp"},{l:"COOL",v:"coolant_temp"},{l:"NVME",v:"nvme_temp"}]
                            delegate: Rectangle { property bool sel: root.mainTempSource === modelData.v; Layout.preferredWidth: 48; Layout.preferredHeight: 22
                                color: sel ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
                                border.color: sel ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border; border.width: 1
                                Text { anchors.centerIn: parent; text: modelData.l; color: sel ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.text; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.mainTempSource = modelData.v; root.save() } } }
                        }
                    }
                    RowLayout { Layout.fillWidth: true; spacing: 8
                        Text { text: "GPU TEMP"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.0; Layout.preferredWidth: 80 }
                        Text { text: root.metricValue(root.gpuTempSource); color: Config.ThemeConfig.colors.secondary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Repeater { model: [{l:"GPU",v:"gpu_temp"},{l:"CPU",v:"cpu_temp"},{l:"NVME",v:"nvme_temp"}]
                            delegate: Rectangle { property bool sel: root.gpuTempSource === modelData.v; Layout.preferredWidth: 48; Layout.preferredHeight: 22
                                color: sel ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
                                border.color: sel ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border; border.width: 1
                                Text { anchors.centerIn: parent; text: modelData.l; color: sel ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.text; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.gpuTempSource = modelData.v; root.save() } } }
                        }
                    }
                    RowLayout { Layout.fillWidth: true; spacing: 8
                        Text { text: "USAGE"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.0; Layout.preferredWidth: 80 }
                        Text { text: root.metricValue(root.usageSource); color: Config.ThemeConfig.colors.secondary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Repeater { model: [{l:"CPU",v:"cpu_usage"},{l:"GPU",v:"gpu_usage"}]
                            delegate: Rectangle { property bool sel: root.usageSource === modelData.v; Layout.preferredWidth: 48; Layout.preferredHeight: 22
                                color: sel ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
                                border.color: sel ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border; border.width: 1
                                Text { anchors.centerIn: parent; text: modelData.l; color: sel ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.text; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.usageSource = modelData.v; root.save() } } }
                        }
                    }
                    RowLayout { Layout.fillWidth: true; spacing: 8
                        Text { text: "RAM SLOT"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.0; Layout.preferredWidth: 80 }
                        Text { text: root.metricValue(root.ramSource); color: Config.ThemeConfig.colors.secondary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Repeater { model: [{l:"RAM",v:"ram_pct"},{l:"SWAP",v:"swap_pct"},{l:"DISK",v:"disk_pct"}]
                            delegate: Rectangle { property bool sel: root.ramSource === modelData.v; Layout.preferredWidth: 48; Layout.preferredHeight: 22
                                color: sel ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
                                border.color: sel ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border; border.width: 1
                                Text { anchors.centerIn: parent; text: modelData.l; color: sel ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.text; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.ramSource = modelData.v; root.save() } } }
                        }
                    }
                    RowLayout { Layout.fillWidth: true; spacing: 8
                        Text { text: "FREQ"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.0; Layout.preferredWidth: 80 }
                        Text { text: root.metricValue("cpu_ghz") + " GHz"; color: Config.ThemeConfig.colors.secondary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Text { text: "FIXED"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                    }
                }
            }

            // ── RIGHT: live rotating LCD preview ───────────────────────────
            CoreCard {
                accent: Config.ThemeConfig.colors.primary; Layout.preferredWidth: 226; Layout.alignment: Qt.AlignTop
                ColumnLayout { Layout.fillWidth: true; spacing: 8
                    RowLayout { Layout.fillWidth: true; spacing: 8
                        Text { text: "󰍛"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; color: Config.ThemeConfig.colors.primary }
                        ColumnLayout { spacing: 1
                            Text { text: "LCD PREVIEW"; color: Config.ThemeConfig.colors.primary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
                            Text { text: root.lcdEnabled ? ("ROT " + root.rotation + "°  •  °" + root.unit) : "DISABLED"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                        }
                    }
                    Item { Layout.fillWidth: true; Layout.preferredWidth: 190; Layout.preferredHeight: 190; Layout.alignment: Qt.AlignHCenter
                        Rectangle { anchors.fill: parent; radius: 16; color: "#000000"; border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
                            Rectangle { anchors.centerIn: parent; width: 168; height: 168; radius: 12; color: "#050505"; clip: true; rotation: root.rotation
                                ColumnLayout { anchors.fill: parent; anchors.margins: 14; spacing: 8
                                    RowLayout { Layout.fillWidth: true
                                        Item { Layout.fillWidth: true }
                                        Text { text: root.metricValue(root.mainTempSource); color: Config.ThemeConfig.colors.primary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 34; font.bold: true }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout { Layout.fillWidth: true; spacing: 6
                                        Text { text: root.metricValue(root.gpuTempSource); color: Config.ThemeConfig.colors.secondary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 15; font.bold: true }
                                        Item { Layout.fillWidth: true }
                                        Text { text: root.metricValue(root.usageSource); color: Config.ThemeConfig.colors.secondary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 15; font.bold: true }
                                    }
                                    RowLayout { Layout.fillWidth: true; spacing: 6
                                        Text { text: root.metricValue(root.ramSource); color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 15; font.bold: true }
                                        Item { Layout.fillWidth: true }
                                        Text { text: root.metricValue("cpu_ghz"); color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 15; font.bold: true }
                                    }
                                }
                            }
                        }
                    }
                    Text { text: "Changes apply live"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                }
            }
        }
    }
}
