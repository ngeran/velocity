// CoreCpuSection.qml — CPU hero: title + temp/avg readouts, 4-wide per-core
// matrix, extended stats, scheduler-load bar. (Items are direct children of the
// CoreCard layout column — no wrapper, so the card can size to content.)

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

CoreCard {
    id: root
    accent: Config.ThemeConfig.colors.primary
    Layout.fillWidth: true

    // ── Header ──────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true; spacing: 10
        ColumnLayout { spacing: 3
            RowLayout { spacing: 6
                Text { text: "󰘚"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; color: Config.ThemeConfig.colors.primary }
                Text { text: "MAIN PROCESSOR ARRAY"; color: Config.ThemeConfig.colors.primary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.5 }
            }
            Text { text: Services.CoreEngineService.perCoreLoad.length + "-CORE // " + Services.CoreEngineService.cpuGhz.toFixed(2) + " GHz BOOST"
                color: Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 20; font.bold: true }
        }
        Item { Layout.fillWidth: true }
        ColumnLayout { spacing: 0
            Text { text: "PACKAGE TEMP"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
            RowLayout { spacing: 2
                Text { text: Services.ThermalService.cpuTemp.toFixed(1); color: Config.ThemeConfig.colors.primary; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 30; font.bold: true }
                Text { text: "°C"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 14; Layout.alignment: Qt.AlignBottom }
            }
        }
        ColumnLayout { spacing: 0
            Text { text: "AVERAGE LOAD"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
            RowLayout { spacing: 2
                Text { text: Math.round(Services.CoreEngineService.cpuUsage); color: Config.ThemeConfig.colors.secondary; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 30; font.bold: true }
                Text { text: "%"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 14; Layout.alignment: Qt.AlignBottom }
            }
        }
    }

    // ── Per-core matrix (4-wide) ────────────────────────────────────────
    GridLayout {
        Layout.fillWidth: true
        columns: 4; rowSpacing: 8; columnSpacing: 8
        Repeater {
            model: Services.CoreEngineService.perCoreLoad
            delegate: Rectangle {
                id: coreTile
                property real load: modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                radius: 3
                color: "transparent"
                border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
                ColumnLayout { anchors.fill: parent; anchors.margins: 6; spacing: 3
                    RowLayout { Layout.fillWidth: true
                        Text { text: "C" + (index + 1).toString().padStart(2, "0"); color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                        Item { Layout.fillWidth: true }
                        Text { text: Math.round(coreTile.load) + "%"; color: Config.ThemeConfig.colors.secondary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
                    }
                    CoreBar { Layout.fillWidth: true; barHeight: 2; value: coreTile.load }
                }
            }
        }
    }

    // ── Extended stats + scheduler load ─────────────────────────────────
    RowLayout {
        Layout.fillWidth: true; spacing: 16
        RowLayout { spacing: 20
            ColumnLayout { spacing: 1
                Text { text: "CORES"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.letterSpacing: 1.0 }
                Text { text: Services.CoreEngineService.perCoreLoad.length + ""; color: Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 14; font.bold: true }
            }
            ColumnLayout { spacing: 1
                Text { text: "CLOCK"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.letterSpacing: 1.0 }
                Text { text: Services.CoreEngineService.cpuGhz.toFixed(2) + " GHz"; color: Config.ThemeConfig.colors.text; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 14; font.bold: true }
            }
            ColumnLayout { spacing: 1
                Text { text: "PEAK TEMP"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.letterSpacing: 1.0 }
                Text { text: Math.round(Services.ThermalService.cpuTemp) + "°C"; color: Config.ThemeConfig.colors.secondary; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 14; font.bold: true }
            }
        }
        Item { Layout.fillWidth: true }
        Rectangle {
            Layout.preferredWidth: 220; Layout.preferredHeight: 30; radius: 3; clip: true
            color: Config.ThemeConfig.colors.outlineVariant; opacity: 0.4
            Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                width: parent.width * (Math.max(0, Math.min(100, Services.CoreEngineService.cpuUsage)) / 100)
                color: Config.ThemeConfig.colors.primary; opacity: 0.12 }
            RowLayout { anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                Text { text: "SCHEDULER LOAD"; color: Config.ThemeConfig.colors.primary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
                Item { Layout.fillWidth: true }
                Text { text: Services.CoreEngineService.cpuUsage > 80 ? "HIGH" : (Services.CoreEngineService.cpuUsage > 40 ? "ACTIVE" : "OPTIMIZED"); color: Config.ThemeConfig.colors.primary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true }
            }
        }
    }
}
