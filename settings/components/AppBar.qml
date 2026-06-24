// =============================================================================
// AppBar.qml — top bar: brand left, status icons right
// =============================================================================

import QtQuick
import "../config" as Config

Rectangle {
    id: bar
    color: Config.ThemeConfig.colors.background

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Config.ThemeConfig.colors.border
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: Config.ControlConfig.padding
        anchors.verticalCenter: parent.verticalCenter
        text: "OBSIDIAN_CORE_OS"
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 13
        font.bold: true
        font.letterSpacing: 2
        color: Config.ThemeConfig.colors.text
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: Config.ControlConfig.padding
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16

        // settings · terminal · power glyphs
        Repeater {
            model: [ "󰒓", ">_", "⏻" ]
            delegate: Text {
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                text: modelData
                color: ma.containsMouse ? Config.ControlConfig.accent : Config.ThemeConfig.colors.textDim
                Behavior on color { ColorAnimation { duration: 120 } }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
