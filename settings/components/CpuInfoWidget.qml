// =============================================================================
// CpuInfoWidget.qml — CPU spec sheet, square-tile layout (Dashboard tab)
// =============================================================================
// CPU readout in bordered square sections (after the dashboard reference):
// header + model headline, a 2×2 tile grid (FREQUENCY / TEMPERATURE / CORES /
// THREADS) — each a big number with its unit stacked beneath, centred in the
// square — and a LOAD footer (average + peak).
//
// Static facts (manufacturer/model/cores/threads) are read ONCE from
// /proc/cpuinfo at load. Live values bind to CoreEngineService.cpuGhz /
// cpuUsage and ThermalService.cpuTemp. Peak load is tracked in-widget.
//
// NB: SplitParser delivers each line WITHOUT its newline, so the buffer
// re-adds "\n" (matches BatteryService) — without it the line keys never match
// and detection stalls on "DETECTING…".
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../config" as Config
import "../services" as Services

Item {
    id: root

    property string cpuModel: ""
    property string cpuMfr: "CPU"
    property int cpuCores: 0
    property int cpuThreads: 0
    property real peakLoad: 0

    function tempTier(t) {
        if (t >= 75) return Config.ThemeConfig.colors.error
        if (t >= 55) return Config.ThemeConfig.colors.warning
        return Config.ThemeConfig.colors.secondary
    }

    function _parseCpuInfo(raw) {
        var threads = 0, model = "", vendor = "", cores = 0
        var lines = (raw || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (line.indexOf("processor") === 0) threads++
            else if (model === "" && line.indexOf("model name") === 0)
                model = line.substring(line.indexOf(":") + 1).trim()
            else if (vendor === "" && line.indexOf("vendor_id") === 0)
                vendor = line.substring(line.indexOf(":") + 1).trim()
            else if (cores === 0 && line.indexOf("cpu cores") === 0)
                cores = parseInt(line.substring(line.indexOf(":") + 1)) || 0
        }
        root.cpuModel = model
        root.cpuThreads = threads || Services.CoreEngineService.perCoreLoad.length
        root.cpuCores = cores || root.cpuThreads || 1

        var mfr = ""
        if (model.length > 0) mfr = model.split(/\s+/)[0].toUpperCase()
        if (mfr.indexOf("INTEL") === 0) mfr = "INTEL"
        else if (mfr.indexOf("AMD") === 0) mfr = "AMD"
        else if (vendor.indexOf("GenuineIntel") === 0) mfr = "INTEL"
        else if (vendor.indexOf("AuthenticAMD") === 0) mfr = "AMD"
        else if (mfr === "") mfr = vendor ? vendor.toUpperCase() : "CPU"
        root.cpuMfr = mfr
        console.log("[CpuInfoWidget] " + root.cpuMfr + " · " + root.cpuModel
                    + " · " + root.cpuCores + "c/" + root.cpuThreads + "t")
    }

    Process {
        id: cpuInfo
        command: ["cat", "/proc/cpuinfo"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { cpuInfo.buffer += data + "\n" } }
        onRunningChanged: if (!running) { root._parseCpuInfo(cpuInfo.buffer); cpuInfo.buffer = "" }
    }

    Connections {
        target: Services.CoreEngineService
        function onCpuUsageChanged() {
            var u = Services.CoreEngineService.cpuUsage
            if (u > root.peakLoad) root.peakLoad = u
        }
    }

    Component.onCompleted: {
        cpuInfo.running = true
        if (Services.CoreEngineService.cpuUsage > root.peakLoad)
            root.peakLoad = Services.CoreEngineService.cpuUsage
    }

    // ---- one bordered square tile: top label + centred (big number + unit) ----
    component Tile : Rectangle {
        property string tileLabel: ""
        property string tileValue: ""
        property string tileUnit: ""
        property color valueColor: Config.ThemeConfig.colors.secondary
        Layout.fillWidth: true; Layout.fillHeight: true
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.3)
        border.color: Config.ThemeConfig.colors.border; border.width: 1
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 6; spacing: 1
            Text { // top label
                text: parent.parent.tileLabel
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 7; font.letterSpacing: 1
                Layout.alignment: Qt.AlignHCenter
            }
            Item { Layout.fillHeight: true }                       // top spacer → centres the pair
            Text { // big value
                text: parent.parent.tileValue
                color: parent.parent.valueColor
                font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 22; font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
            Text { // unit beneath
                text: parent.parent.tileUnit
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.letterSpacing: 1
                Layout.alignment: Qt.AlignHCenter
            }
            Item { Layout.fillHeight: true }                       // bottom spacer → centres the pair
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 8

        // ── header ──
        RowLayout {
            Layout.fillWidth: true
            WidgetHeader { icon: "󰘚"; label: "CPU"; iconColor: Config.ThemeConfig.colors.secondary }
            Item { Layout.fillWidth: true }
            Rectangle {
                height: 15; width: mfrTxt.implicitWidth + 10
                color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.10)
                border.color: Config.ThemeConfig.colors.secondary; border.width: 1
                Text {
                    id: mfrTxt; anchors.centerIn: parent
                    text: root.cpuMfr
                    color: Config.ThemeConfig.colors.secondary
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 7; font.bold: true
                }
            }
        }

        // ── model headline ──
        Text {
            Layout.fillWidth: true
            text: root.cpuModel.length > 0 ? root.cpuModel : "DETECTING…"
            color: Config.ThemeConfig.colors.text
            font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 12; font.bold: true
            wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
        }

        // ── 2×2 square tiles ──
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            rowSpacing: 6; columnSpacing: 6

            Tile {
                tileLabel: "FREQUENCY"
                tileValue: Services.CoreEngineService.cpuGhz.toFixed(2)
                tileUnit: "GHz"
                valueColor: Config.ThemeConfig.colors.secondary
            }
            Tile {
                tileLabel: "TEMPERATURE"
                tileValue: Math.round(Services.ThermalService.cpuTemp).toString()
                tileUnit: "°C"
                valueColor: root.tempTier(Services.ThermalService.cpuTemp)
            }
            Tile {
                tileLabel: "CORES"
                tileValue: (root.cpuCores || Services.CoreEngineService.perCoreLoad.length || 0).toString()
                tileUnit: "PHYSICAL"
                valueColor: Config.ThemeConfig.colors.text
            }
            Tile {
                tileLabel: "THREADS"
                tileValue: (root.cpuThreads || Services.CoreEngineService.perCoreLoad.length || 0).toString()
                tileUnit: "LOGICAL"
                valueColor: Config.ThemeConfig.colors.text
            }
        }

        // ── footer: load average + peak ──
        ColumnLayout { Layout.fillWidth: true; spacing: 4
            RowLayout { Layout.fillWidth: true
                Text { text: "AVG LOAD"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.letterSpacing: 1 }
                Text { text: Math.round(Services.CoreEngineService.cpuUsage) + "%"
                    color: Config.ThemeConfig.colors.secondary
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
                Item { Layout.fillWidth: true }
                Text { text: "PEAK"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.letterSpacing: 1 }
                Text { text: Math.round(root.peakLoad) + "%"
                    color: Config.ThemeConfig.colors.warning
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
            }
            CoreBar { Layout.fillWidth: true; barHeight: 5; value: Services.CoreEngineService.cpuUsage; barColor: Config.ThemeConfig.colors.secondary }
        }
    }
}
