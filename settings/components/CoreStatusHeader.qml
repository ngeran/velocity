// CoreStatusHeader.qml — system status bar (nominal dot + kernel + readouts).

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

CoreCard {
    id: root
    accent: Config.ThemeConfig.colors.primary
    Layout.fillWidth: true
    implicitHeight: 58

    RowLayout {
        Layout.fillWidth: true
        spacing: 16

        RowLayout {
            spacing: 8
            Rectangle {
                width: 8; height: 8; radius: 4; color: Config.ThemeConfig.colors.primary
                SequentialAnimation on opacity { loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 700 } NumberAnimation { to: 1; duration: 700 } }
            }
            Text { text: "SYSTEM STATUS: NOMINAL"; color: Config.ThemeConfig.colors.primary
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.5 }
        }

        Rectangle { width: 1; Layout.fillHeight: true; color: Config.ThemeConfig.colors.border }
        Text { text: "KERNEL: " + Services.SysInfoService.kernel; color: Config.ThemeConfig.colors.textDim
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }
        Rectangle { width: 1; Layout.fillHeight: true; color: Config.ThemeConfig.colors.border }

        // Motherboard model + parsed chipset badge (DMI identity)
        RowLayout {
            spacing: 6
            Text {
                text: "BOARD: "
                      + (Services.SysInfoService.boardVendor !== "—" && Services.SysInfoService.boardVendor.length > 0
                         ? Services.SysInfoService.boardVendor + " " : "")
                      + Services.SysInfoService.boardName
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                elide: Text.ElideRight; Layout.maximumWidth: 250
            }
            Rectangle {
                visible: Services.SysInfoService.chipset !== "—" && Services.SysInfoService.chipset.length > 0
                border.color: Config.ThemeConfig.colors.secondary; border.width: 1
                height: 14; width: csChip.implicitWidth + 10
                Text {
                    id: csChip; anchors.centerIn: parent
                    text: Services.SysInfoService.chipset
                    color: Config.ThemeConfig.colors.secondary
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 7; font.bold: true
                }
            }
        }

        Item { Layout.fillWidth: true }

        // readouts
        ColumnLayout { spacing: 0
            Text { text: "UPTIME"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
            Text { text: Services.SysInfoService.uptime; color: Config.ThemeConfig.colors.secondary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true; elide: Text.ElideRight }
        }
        ColumnLayout { spacing: 0
            Text { text: "GPU PWR"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
            Text { text: Math.round(Services.GpuService.powerW) + "W"; color: Config.ThemeConfig.colors.secondary; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
        }
        ColumnLayout { spacing: 0
            Text { text: "CPU TEMP"; color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
            Text { text: Math.round(Services.ThermalService.cpuTemp) + "°"; color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
        }
    }
}
