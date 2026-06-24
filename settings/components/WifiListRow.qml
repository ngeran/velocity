// =============================================================================
// WifiListRow.qml — one wifi network row (click = connect)
// =============================================================================

import QtQuick
import "../config" as Config
import "../services" as Services

Item {
    id: row
    width: parent ? parent.width : 400
    height: 22
    property var net: ({ ssid: "", signal: 0, security: "", inUse: false })

    Rectangle {
        anchors.fill: parent
        color: ma.containsMouse ? Config.ControlConfig.accentSoft : "transparent"
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 4
        spacing: 8

        // in-use indicator
        Text {
            width: 14
            text: row.net.inUse ? "●" : "○"
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 12
            color: row.net.inUse ? Config.ControlConfig.accent : Config.ThemeConfig.colors.border
        }

        // SSID
        Text {
            width: 180
            text: row.net.ssid
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 11
            color: row.net.inUse ? Config.ControlConfig.accent : Config.ThemeConfig.colors.text
            elide: Text.ElideRight
        }

        // Signal bar + %
        Item {
            width: 90
            height: 14
            Rectangle {
                id: barTrack
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 60
                height: 4
                color: "#1a1a1a"
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, row.net.signal / 100))
                    height: parent.height
                    color: Config.ControlConfig.accent
                }
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: row.net.signal + "%"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 10
                color: Config.ThemeConfig.colors.textDim
            }
        }

        // Security
        Text {
            text: (row.net.security && row.net.security.length > 0) ? row.net.security : "open"
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Services.NetworkControlService.connectWifi(row.net.ssid, "")
    }
}
