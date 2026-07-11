// =============================================================================
// BrightnessControlView.qml — Brightness control UI for Control tab
// =============================================================================
//
// Provides brightness slider and quick-adjust buttons for screen brightness.
// Uses BrightnessService to communicate with brightnessctl.
//
// =============================================================================

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../config" as Config
import "../services" as Services

Item {
    id: root
    implicitWidth: 400
    implicitHeight: 120

    // =========================================================================
    // BRIGHTNESS SLIDER
    // =========================================================================

    Column {
        anchors.fill: parent
        spacing: 12

        // Header with icon and percentage
        RowLayout {
            spacing: 12

            Text {
                text: "󰃜"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 20
                color: Config.ThemeConfig.colors.text
            }

            Text {
                text: "BRIGHTNESS"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: Config.ControlConfig.fontHeadline
                font.bold: true
                color: Config.ThemeConfig.colors.text
            }

            Item { Layout.fillWidth: true }

            Text {
                text: Services.BrightnessService.brightness + "%"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: Config.ControlConfig.fontHeadline
                font.bold: true
                color: Config.ControlConfig.accent
            }
        }

        // Slider
        RowLayout {
            spacing: 12

            // Min button
            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 32
                radius: Config.SettingsConfig.radiusMd
                color: Config.ThemeConfig.colors.surface
                border.color: Config.ThemeConfig.colors.border
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰃛"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: Config.ThemeConfig.colors.text
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Services.BrightnessService.setBrightness(0)
                }
            }

            // Slider
            Slider {
                Layout.fillWidth: true
                from: 0
                to: 100
                value: Services.BrightnessService.brightness

                background: Rectangle {
                    width: parent.availableWidth
                    height: 4
                    radius: 2
                    color: Config.ThemeConfig.colors.surfaceVariant

                    Rectangle {
                        width: parent.width * (parent.parent.value / parent.parent.to)
                        height: parent.height
                        radius: parent.radius
                        color: Config.ControlConfig.accent
                    }
                }

                handle: Rectangle {
                    implicitWidth: 16
                    implicitHeight: 16
                    radius: Config.SettingsConfig.radiusMd
                    color: Config.ThemeConfig.colors.background
                    border.color: Config.ControlConfig.accent
                    border.width: 2

                    Rectangle {
                        anchors.centerIn: parent
                        width: 4
                        height: 4
                        radius: Config.SettingsConfig.radiusMd
                        color: Config.ControlConfig.accent
                    }
                }

                onMoved: {
                    Services.BrightnessService.setBrightness(value)
                }
            }

            // Max button
            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 32
                radius: Config.SettingsConfig.radiusMd
                color: Config.ThemeConfig.colors.surface
                border.color: Config.ThemeConfig.colors.border
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰃜"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: Config.ThemeConfig.colors.text
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Services.BrightnessService.setBrightness(100)
                }
            }
        }

        // Quick adjustment buttons
        RowLayout {
            spacing: 8

            Repeater {
                model: [25, 50, 75, 100]

                Rectangle {
                    Layout.preferredWidth: 55
                    Layout.preferredHeight: 28
                    radius: Config.SettingsConfig.radiusMd
                    color: Services.BrightnessService.brightness === modelData ? Config.ControlConfig.accentSoft : Config.ThemeConfig.colors.surfaceVariant
                    border.color: Services.BrightnessService.brightness === modelData ? Config.ControlConfig.accent : Config.ThemeConfig.colors.border
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData + "%"
                        font.family: Config.ControlConfig.fontMono
                        font.pixelSize: 10
                        color: Services.BrightnessService.brightness === modelData ? Config.ControlConfig.accent : Config.ThemeConfig.colors.text
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.BrightnessService.setBrightness(modelData)
                    }
                }
            }
        }
    }
}
