// =============================================================================
// SourceRow.qml — single audio source row (microphone)
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Rectangle {
    id: row
    required property var source

    width: parent.width
    height: 40
    radius: 0
    color: Config.ThemeConfig.colors.surfaceVariant
    border.color: row.source.isDefault ? Config.ControlConfig.accent : Config.ThemeConfig.colors.border
    border.width: row.source.isDefault ? 1 : 0

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        // Mute icon
        Text {
            text: row.source.mute ? "󰝟" : "󰝰"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: row.source.mute ? Config.ThemeConfig.colors.error : Config.ThemeConfig.colors.success
            Layout.preferredWidth: 20
        }

        // Source name
        Text {
            text: row.source.name || "Unknown"
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 11
            color: Config.ThemeConfig.colors.text
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        // Volume bar
        Rectangle {
            Layout.preferredWidth: 80
            Layout.preferredHeight: 6
            radius: 0
            color: Config.ThemeConfig.colors.background

            Rectangle {
                width: parent.width * (row.source.volume / 100)
                height: parent.height
                radius: 0
                color: row.source.mute ? Config.ThemeConfig.colors.textDim : Config.ControlConfig.accent
            }
        }

        // Volume percentage
        Text {
            text: row.source.volume + "%"
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
            Layout.preferredWidth: 30
        }

        // Default badge
        Rectangle {
            visible: row.source.isDefault
            Layout.preferredWidth: 40
            Layout.preferredHeight: 16
            radius: 0
            color: Config.ControlConfig.accent

            Text {
                anchors.centerIn: parent
                text: "DEF"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 8
                font.bold: true
                color: Config.ThemeConfig.colors.background
            }
        }

        // Mute toggle
        Rectangle {
            Layout.preferredWidth: 50
            Layout.preferredHeight: 24
            radius: 0
            color: row.source.mute ? Config.ThemeConfig.colors.error : Config.ThemeConfig.colors.surface
            border.color: Config.ThemeConfig.colors.border
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: row.source.mute ? "UNMUTE" : "MUTE"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 8
                color: row.source.mute ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.text
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.AudioControlService.toggleSourceMute(row.source.id)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (!row.source.isDefault) {
                Services.AudioControlService.setDefaultSource(row.source.id)
            }
        }
    }
}
