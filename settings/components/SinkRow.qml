// =============================================================================
// SinkRow.qml — one output sink: set-default (click name) · mute · volume bar
// =============================================================================

import QtQuick
import "../config" as Config
import "../services" as Services

Item {
    id: row
    width: parent ? parent.width : 400
    height: 26
    property var sink: ({ index: -1, name: "", desc: "", isDefault: false, volume: 0, mute: false })

    Rectangle {
        anchors.fill: parent
        color: nameMa.containsMouse ? Config.ControlConfig.accentSoft : "transparent"
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 4
        spacing: 8

        // default marker
        Text {
            width: 14
            text: row.sink.isDefault ? "▸" : ""
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 12
            font.bold: true
            color: Config.ControlConfig.accent
        }

        // description (click → set default)
        Text {
            id: descText
            width: 170
            text: row.sink.desc || row.sink.name
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 11
            color: row.sink.isDefault ? Config.ControlConfig.accent : Config.ThemeConfig.colors.text
            elide: Text.ElideRight
            MouseArea {
                id: nameMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.AudioControlService.setDefaultSink(row.sink.name)
            }
        }

        // mute toggle
        Rectangle {
            width: 26
            height: 18
            anchors.verticalCenter: parent.verticalCenter
            radius: 0
            color: muteMa.containsMouse ? Config.ThemeConfig.colors.border : "transparent"
            border.color: Config.ThemeConfig.colors.border
            border.width: 1
            Text {
                anchors.centerIn: parent
                text: row.sink.mute ? "󰝟" : "󰕾"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: row.sink.mute ? Config.ControlConfig.logError : Config.ThemeConfig.colors.textDim
            }
            MouseArea {
                id: muteMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.AudioControlService.toggleSinkMute(row.sink.name)
            }
        }

        // volume bar (click to set)
        Item {
            width: 120
            height: 18
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: volTrack
                anchors.verticalCenter: parent.verticalCenter
                width: 120
                height: 6
                color: Config.ThemeConfig.colors.border
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, row.sink.volume / 100))
                    height: parent.height
                    color: row.sink.mute ? Config.ThemeConfig.colors.textDim : Config.ControlConfig.accent
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var pct = Math.round(Math.max(0, Math.min(1, mouseX / volTrack.width)) * 100)
                        Services.AudioControlService.setSinkVolume(row.sink.name, pct + "%")
                    }
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: row.sink.volume + "%"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 10
                color: Config.ThemeConfig.colors.textDim
            }
        }
    }
}
