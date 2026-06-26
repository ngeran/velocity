// =============================================================================
// ResourcesWidget.qml — System resources for the dashboard bento grid
// =============================================================================
// CPU / MEM / GPU rows (glyph + label + % + bar), disk pinned to the bottom.
// Colour-coded: accent < 70%, warning 70–89%, error >= 90%.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services
import "." as Components

Item {
    id: root

    property real cpuUsage:  Services.SysInfoService.cpuPercent
    property real memUsage:  Services.SysInfoService.memPercent
    property real gpuUsage:  Services.SysInfoService.gpuPercent
    property real diskUsage: Services.SysInfoService.diskPercent

    function barColor(pct) {
        if (pct >= 90) return Config.ThemeConfig.colors.error
        if (pct >= 70) return Config.ThemeConfig.colors.warning
        return Config.ThemeConfig.colors.secondary
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Components.WidgetHeader {
            icon: "󰓅"
            label: "RESOURCES"
            Layout.bottomMargin: 14
        }

        // CPU / MEM / GPU
        Repeater {
            model: [
                { label: "CPU", glyph: "󰻠", value: root.cpuUsage },
                { label: "MEM", glyph: "󰍛", value: root.memUsage },
                { label: "GPU", glyph: "󰢮", value: root.gpuUsage }
            ]
            delegate: ColumnLayout {
                id: metric
                Layout.fillWidth: true
                spacing: 4
                Layout.bottomMargin: 10
                readonly property real value: modelData.value

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        text: modelData.glyph
                        color: root.barColor(metric.value)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                    Text {
                        text: modelData.label
                        color: Config.ThemeConfig.colors.textDim
                        font.pixelSize: 8
                        font.family: Config.SettingsConfig.fontFamily
                        font.letterSpacing: 1.5
                        Layout.fillWidth: true
                    }
                    Text {
                        text: Math.round(metric.value) + "%"
                        color: root.barColor(metric.value)
                        font.pixelSize: 10; font.bold: true
                        font.family: Config.SettingsConfig.fontFamily
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 3
                    color: Config.ThemeConfig.colors.surfaceVariant

                    Rectangle {
                        width: parent.width * (metric.value / 100)
                        height: parent.height
                        color: root.barColor(metric.value)
                        Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Disk
        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant; Layout.bottomMargin: 8 }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                text: ""
                color: Config.ThemeConfig.colors.textDim
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
            }
            Text {
                text: "DISK / ROOT"
                color: Config.ThemeConfig.colors.textDim
                font.pixelSize: 8
                font.family: Config.SettingsConfig.fontFamily
                font.letterSpacing: 1.5
                Layout.fillWidth: true
            }
            Text {
                text: Math.round(root.diskUsage) + "%"
                color: Config.ThemeConfig.colors.textDim
                font.pixelSize: 10; font.bold: true
                font.family: Config.SettingsConfig.fontFamily
            }
        }
    }
}
