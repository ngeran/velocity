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

    // Section buttons
    Column {
        id: navList
        anchors.top: parent.top
        anchors.topMargin: 18
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
                    color: del.active ? Config.ControlConfig.accentSoft : (navMa.containsMouse ? Config.ControlConfig.accentSoft : "transparent")
                    opacity: del.active ? 1.0 : (navMa.containsMouse ? 0.5 : 1.0)
                    border.color: del.active ? Config.ControlConfig.accent : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
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
                        color: (del.active || navMa.containsMouse) ? Config.ControlConfig.accent : Config.ThemeConfig.colors.textDim
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Text {
                        text: modelData.label
                        font.family: Config.ControlConfig.fontMono
                        font.pixelSize: 11
                        font.letterSpacing: 1
                        color: (del.active || navMa.containsMouse) ? Config.ControlConfig.accent : Config.ThemeConfig.colors.textDim
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                MouseArea {
                    id: navMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: nav.sectionSelected(modelData.key)
                }
            }
        }
    }
}
