// =============================================================================
// BtDeviceRow.qml — one bluetooth device row (click toggles connect/disconnect)
// =============================================================================

import QtQuick
import "../config" as Config
import "../services" as Services

Item {
    id: row
    width: parent ? parent.width : 400
    height: 24
    property var dev: ({ mac: "", name: "", connected: false, paired: false, trusted: false, battery: -1 })

    Rectangle {
        anchors.fill: parent
        color: ma.containsMouse ? Config.ControlConfig.accentSoft : "transparent"
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 4
        spacing: 8

        Text {
            width: 14
            text: row.dev.connected ? "●" : "○"
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 12
            color: row.dev.connected ? Config.ControlConfig.accent : Config.ThemeConfig.colors.border
        }

        Text {
            width: 150
            text: row.dev.name || row.dev.mac
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 11
            color: row.dev.connected ? Config.ControlConfig.accent : Config.ThemeConfig.colors.text
            elide: Text.ElideRight
        }

        Text {
            width: 140
            text: row.dev.mac
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
            elide: Text.ElideRight
        }

        Text {
            width: 64
            text: row.dev.paired ? "PAIRED" : "—"
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 9
            font.bold: true
            color: row.dev.paired ? Config.ControlConfig.logSuccess : Config.ThemeConfig.colors.textDim
        }

        Text {
            width: 64
            text: row.dev.trusted ? "TRUSTED" : ""
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 9
            font.bold: true
            color: Config.ControlConfig.accent
        }

        Text {
            text: row.dev.battery >= 0 ? (row.dev.battery + "%") : ""
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
        onClicked: {
            if (row.dev.connected) Services.BluetoothControlService.disconnect(row.dev.mac)
            else Services.BluetoothControlService.connect(row.dev.mac)
        }
    }
}
