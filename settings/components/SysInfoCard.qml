// =============================================================================
// SysInfoCard.qml — System Information Display Card
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Rectangle {
    id: root
    implicitWidth: 280
    implicitHeight: 140

    color: Config.ThemeConfig.colors.surface
    border.color: Config.ThemeConfig.colors.border
    border.width: 1
    radius: 0

    Column {
        anchors {
            fill: parent
            margins: 14
        }
        spacing: 8

        // Header
        Text {
            text: "SYSTEM INFORMATION"
            font.pixelSize: 8
            font.family: "monospace"
            font.letterSpacing: 1.5
            color: Config.ThemeConfig.colors.textDim
        }

        // System info
        Column {
            spacing: 4

            Row {
                spacing: 8
                Text {
                    text: "OS:"
                    font.pixelSize: 9
                    font.family: "monospace"
                    color: Config.ThemeConfig.colors.textDim
                    width: 40
                }
                Text {
                    text: Services.SysInfoService.osPrettyName
                    font.pixelSize: 9
                    font.family: "monospace"
                    color: Config.ThemeConfig.colors.text
                }
            }

            Row {
                spacing: 8
                Text {
                    text: "Kernel:"
                    font.pixelSize: 9
                    font.family: "monospace"
                    color: Config.ThemeConfig.colors.textDim
                    width: 40
                }
                Text {
                    text: Services.SysInfoService.kernel
                    font.pixelSize: 9
                    font.family: "monospace"
                    color: Config.ThemeConfig.colors.text
                }
            }

            Row {
                spacing: 8
                Text {
                    text: "Host:"
                    font.pixelSize: 9
                    font.family: "monospace"
                    color: Config.ThemeConfig.colors.textDim
                    width: 40
                }
                Text {
                    text: Services.SysInfoService.hostname
                    font.pixelSize: 9
                    font.family: "monospace"
                    color: Config.ThemeConfig.colors.text
                }
            }

            Row {
                spacing: 8
                Text {
                    text: "Uptime:"
                    font.pixelSize: 9
                    font.family: "monospace"
                    color: Config.ThemeConfig.colors.textDim
                    width: 40
                }
                Text {
                    text: Services.SysInfoService.uptime
                    font.pixelSize: 9
                    font.family: "monospace"
                    color: Config.ThemeConfig.colors.text
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Device info
        Row {
            spacing: 8
            Text {
                text: "User:"
                font.pixelSize: 9
                font.family: "monospace"
                color: Config.ThemeConfig.colors.textDim
            }
            Text {
                text: Services.SysInfoService.userName
                font.pixelSize: 9
                font.family: "monospace"
                color: Config.ThemeConfig.colors.secondary
            }
        }
    }
}
