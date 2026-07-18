// CoreGpuSection.qml — GPU: utilization gauge + clock/power/fan/hotspot rows.
// (Direct children of CoreCard's layout column.)

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

CoreCard {
    id: root
    accent: Config.ThemeConfig.colors.secondary
    Layout.fillWidth: true

    // ── Header ──────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        ColumnLayout { spacing: 2
            Text { text: "NVIDIA-SMI / DEVICE 0"; color: Config.ThemeConfig.colors.secondary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.5 }
            Text { text: Services.GpuService.present ? "GPU CORE" : "NO NVIDIA GPU"; color: Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 20; font.bold: true }
        }
        Item { Layout.fillWidth: true }
        Text { text: "󰢮"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 26; color: Config.ThemeConfig.colors.secondary; opacity: 0.6 }
    }

    // ── Gauge + metrics ─────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true; spacing: 20
        Item {
            Layout.preferredWidth: 130; Layout.preferredHeight: 130
            CoreGauge { anchors.fill: parent; value: Services.GpuService.util; arcColor: Config.ThemeConfig.colors.secondary }
            Column { anchors.centerIn: parent; spacing: 1
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(Services.GpuService.util) + "%"; color: Config.ThemeConfig.colors.secondary; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 30; font.bold: true }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "GPU LOAD"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.letterSpacing: 1.0 }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [
                    { label: "CLOCK SPEED", value: Services.GpuService.clockMHz.toFixed(0) + " MHz", hot: false },
                    { label: "POWER DRAW", value: Services.GpuService.powerW.toFixed(0) + " W", hot: false },
                    { label: "FAN DUTY", value: Services.GpuService.fanPct.toFixed(0) + " %", hot: false },
                    { label: "HOT SPOT", value: Math.round(Services.GpuService.temp) + " °C", hot: true }
                ]
                delegate: Item {
                    Layout.fillWidth: true; Layout.preferredHeight: 22
                    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Config.ThemeConfig.colors.outlineVariant }
                    RowLayout { anchors.fill: parent
                        Text { text: modelData.label; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
                        Item { Layout.fillWidth: true }
                        Text { text: modelData.value; color: modelData.hot ? Config.ThemeConfig.colors.primary : Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 13; font.bold: true }
                    }
                }
            }
        }
    }
}
