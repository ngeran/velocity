// =============================================================================
// SinkInputRow.qml — one active stream: app · mute · per-stream volume bar
// =============================================================================

import QtQuick
import "../config" as Config
import "../services" as Services

Item {
    id: row
    width: parent ? parent.width : 400
    height: 24
    property var stream: ({ id: "", app: "", sink: "", volume: 0, mute: false })

    Rectangle {
        anchors.fill: parent
        color: "transparent"
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 4
        spacing: 8

        // indent marker (a stream, not a sink)
        Text {
            width: 14
            text: "•"
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 12
            color: Config.ThemeConfig.colors.textDim
        }

        // app name + routed sink
        Text {
            width: 170
            text: row.stream.app + (row._sinkLabel.length > 0 ? "  → " + row._sinkLabel : "")
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 11
            color: Config.ThemeConfig.colors.text
            elide: Text.ElideRight
        }

        // mute toggle
        Rectangle {
            width: 26
            height: 18
            anchors.verticalCenter: parent.verticalCenter
            radius: 3
            color: muteMa.containsMouse ? Config.ThemeConfig.colors.border : "transparent"
            border.color: Config.ThemeConfig.colors.border
            border.width: 1
            Text {
                anchors.centerIn: parent
                text: row.stream.mute ? "󰝟" : "󰕾"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: row.stream.mute ? Config.ControlConfig.logError : Config.ThemeConfig.colors.textDim
            }
            MouseArea {
                id: muteMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.AudioControlService.toggleSinkInputMute(row.stream.id)
            }
        }

        // per-stream volume bar (click to set)
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
                    width: parent.width * Math.max(0, Math.min(1, row.stream.volume / 100))
                    height: parent.height
                    color: row.stream.mute ? Config.ThemeConfig.colors.textDim : Config.ControlConfig.accent
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var pct = Math.round(Math.max(0, Math.min(1, mouseX / volTrack.width)) * 100)
                        Services.AudioControlService.setSinkInputVolume(row.stream.id, pct + "%")
                    }
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: row.stream.volume + "%"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 10
                color: Config.ThemeConfig.colors.textDim
            }
        }
    }

    // resolve sink index → human label
    property string _sinkLabel: {
        if (!row.stream.sink || row.stream.sink.length === 0) return ""
        var idx = parseInt(row.stream.sink)
        var sinks = Services.AudioControlService.sinks
        for (var i = 0; i < sinks.length; i++) {
            if (sinks[i].index === idx) return sinks[i].desc || sinks[i].name
        }
        return "#" + row.stream.sink
    }
}
