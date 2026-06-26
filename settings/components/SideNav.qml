// =============================================================================
// SideNav.qml — vertical section switcher (network / bluetooth / audio / system)
// =============================================================================

import QtQuick
import "../config" as Config

Rectangle {
    id: nav
    color: Config.ThemeConfig.colors.surface

    signal sectionSelected(string key)
    property string activeSection: "network"

    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 1
        color: Config.ThemeConfig.colors.border
    }

    // Brand block
    Column {
        anchors.top: parent.top
        anchors.topMargin: 18
        anchors.left: parent.left
        anchors.leftMargin: 14
        spacing: 2

        Text {
            text: "ROOT@HYPR"
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 14
            font.bold: true
            color: Config.ControlConfig.accent
        }
        Text {
            text: "V0.4.2-STABLE"
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
        }
    }

    // Section buttons
    Column {
        id: navList
        anchors.top: parent.top
        anchors.topMargin: 72
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 4

        Repeater {
            model: Config.ControlConfig.sections
            delegate: Item {
                id: del
                width: nav.width - 16
                height: 38
                x: 8
                property bool active: (modelData.key === nav.activeSection)

                Rectangle {
                    anchors.fill: parent
                    radius: Config.ControlConfig.radius
                    color: del.active ? Config.ControlConfig.accentSoft : "transparent"
                    border.color: del.active ? Config.ControlConfig.accent : "transparent"
                    border.width: 1
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    spacing: 10

                    Text {
                        text: modelData.icon
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: del.active ? Config.ControlConfig.accent : Config.ThemeConfig.colors.textDim
                    }
                    Text {
                        text: modelData.label
                        font.family: Config.ControlConfig.fontMono
                        font.pixelSize: 11
                        font.letterSpacing: 1
                        color: del.active ? Config.ControlConfig.accent : Config.ThemeConfig.colors.textDim
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: nav.sectionSelected(modelData.key)
                }
            }
        }
    }
}
