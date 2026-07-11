// =============================================================================
// MprisControlView.qml — Media Player Control UI
// =============================================================================
//
// Provides play/pause/next/previous controls and track info display.
// Uses MprisService to communicate with playerctl.
//
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Item {
    id: root
    implicitWidth: 400
    implicitHeight: 180

    Column {
        anchors.fill: parent
        spacing: 12

        // Header with icon and status
        RowLayout {
            spacing: 12

            Text {
                text: "󰝧"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 20
                color: Config.ThemeConfig.colors.text
            }

            Text {
                text: "MEDIA"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: Config.ControlConfig.fontHeadline
                font.bold: true
                color: Config.ThemeConfig.colors.text
            }

            Item { Layout.fillWidth: true }

            Text {
                text: Services.MprisService.player.length > 0 ? Services.MprisService.player : "NO PLAYER"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 10
                color: Config.ThemeConfig.colors.textDim
                font.letterSpacing: 1
            }
        }

        // Track info card
        Rectangle {
            width: parent.width
            height: 60
            radius: Config.SettingsConfig.radiusMd
            color: Config.ThemeConfig.colors.surfaceVariant
            border.color: Config.ThemeConfig.colors.border
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4

                Text {
                    text: Services.MprisService.canControl ? Services.MprisService.title : "No track playing"
                    font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 12
                    font.bold: true
                    color: Config.ThemeConfig.colors.text
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: Services.MprisService.artist
                    font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 11
                    color: Config.ThemeConfig.colors.textDim
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    visible: Services.MprisService.canControl && Services.MprisService.artist.length > 0
                }

                Item { Layout.fillHeight: true }

                Text {
                    text: Services.MprisService.status.toUpperCase()
                    font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                    color: Services.MprisService.status === "playing" ? Config.ThemeConfig.colors.success :
                          Services.MprisService.status === "paused" ? Config.ThemeConfig.colors.warning :
                          Config.ThemeConfig.colors.textDim
                    Layout.alignment: Qt.AlignRight
                }
            }
        }

        // Playback controls
        RowLayout {
            spacing: 8

            // Previous
            Rectangle {
                Layout.preferredWidth: 70
                Layout.preferredHeight: 40
                radius: Config.SettingsConfig.radiusMd
                color: Config.ThemeConfig.colors.surface
                border.color: Config.ThemeConfig.colors.border
                border.width: 1
                enabled: Services.MprisService.canControl
                opacity: enabled ? 1.0 : 0.4

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: "󰒮"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: Config.ThemeConfig.colors.text
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "PREV"
                        font.family: Config.ControlConfig.fontMono
                        font.pixelSize: 9
                        color: Config.ThemeConfig.colors.textDim
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: Services.MprisService.previous()
                }
            }

            // Play/Pause
            Rectangle {
                Layout.preferredWidth: 90
                Layout.preferredHeight: 40
                radius: Config.SettingsConfig.radiusMd
                color: Services.MprisService.status === "playing" ? Config.ThemeConfig.colors.surfaceVariant : Config.ThemeConfig.colors.secondary
                border.color: Config.ThemeConfig.colors.border
                border.width: 1
                enabled: Services.MprisService.canControl
                opacity: enabled ? 1.0 : 0.4

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: Services.MprisService.status === "playing" ? "󰏤" : Services.MprisService.status === "paused" ? "󰐊" : "󰐊"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: Services.MprisService.status === "playing" ? Config.ThemeConfig.colors.text : Config.ThemeConfig.colors.background
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: Services.MprisService.status === "playing" ? "PAUSE" : "PLAY"
                        font.family: Config.ControlConfig.fontMono
                        font.pixelSize: 9
                        font.bold: true
                        color: Services.MprisService.status === "playing" ? Config.ThemeConfig.colors.text : Config.ThemeConfig.colors.background
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: Services.MprisService.playPause()
                }
            }

            // Next
            Rectangle {
                Layout.preferredWidth: 70
                Layout.preferredHeight: 40
                radius: Config.SettingsConfig.radiusMd
                color: Config.ThemeConfig.colors.surface
                border.color: Config.ThemeConfig.colors.border
                border.width: 1
                enabled: Services.MprisService.canControl
                opacity: enabled ? 1.0 : 0.4

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: "󰒭"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: Config.ThemeConfig.colors.text
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "NEXT"
                        font.family: Config.ControlConfig.fontMono
                        font.pixelSize: 9
                        color: Config.ThemeConfig.colors.textDim
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: Services.MprisService.next()
                }
            }

            Item { Layout.fillWidth: true }

            // Stop
            Rectangle {
                Layout.preferredWidth: 50
                Layout.preferredHeight: 40
                radius: Config.SettingsConfig.radiusMd
                color: Config.ThemeConfig.colors.error
                border.color: Config.ThemeConfig.colors.border
                border.width: 1
                enabled: Services.MprisService.canControl
                opacity: enabled ? 1.0 : 0.4

                Text {
                    anchors.centerIn: parent
                    text: "󰛳"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: Config.ThemeConfig.colors.background
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: Services.MprisService.stop()
                }
            }
        }
    }
}
