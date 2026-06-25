// =============================================================================
// StatusCard.qml — reusable single status card (title · line1 · line2 · dot)
// =============================================================================

import QtQuick
import "../config" as Config

Rectangle {
    id: card
    property string title: ""
    property string line1: ""
    property string line2: ""
    property bool active: false

    radius: Config.ControlConfig.radius
    color: "#050505"
    border.width: 0

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 4

        // Header: title left, status dot right
        Item {
            width: parent.width
            height: 12

            Text {
                id: titleText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: card.title
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.5
                color: card.active ? Config.ControlConfig.accent : Config.ThemeConfig.colors.textDim
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: card.active ? Config.ControlConfig.accent : Config.ThemeConfig.colors.border
            }
        }

        Text {
            text: card.line1
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 12
            color: card.active ? Config.ControlConfig.accent : Config.ThemeConfig.colors.text
        }

        Text {
            text: card.line2
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
        }
    }
}
