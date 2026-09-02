// =============================================================================
// SideNav.qml — vertical section switcher (network / bluetooth / audio / display)
// =============================================================================
// NavRailItem pattern: icon chip + label, active tint + dot. Collapses to
// icon-only (56px) when UIScale reports the compact breakpoint (<1440 logical).
// =============================================================================

import QtQuick
import "../config" as Config

Rectangle {
    id: nav
    color: Config.ThemeConfig.colors.surface

    signal sectionSelected(string key)
    property string activeSection: "network"
    // Section model ({key,label,icon}) — defaults to the Controls sections;
    // other tabs (e.g. Core) pass their own.
    property var items: Config.ControlConfig.sections
    // Optional footer slot pinned to the rail's bottom (e.g. session info).
    default property alias footer: footerSlot.data

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
        anchors.topMargin: Config.ControlConfig.space4
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Config.ControlConfig.space1

        Repeater {
            model: nav.items
            delegate: Item {
                id: del
                width: nav.width - Config.ControlConfig.space2
                height: 40
                x: Config.ControlConfig.space1
                property bool active: (modelData.key === nav.activeSection)

                Rectangle {
                    anchors.fill: parent
                    radius: Config.ControlConfig.radiusPill
                    color: del.active ? Config.ControlConfig.accentSoft
                           : (navMa.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.text, 0.05) : "transparent")
                    opacity: del.active ? 1.0 : (navMa.containsMouse ? 0.6 : 1.0)
                    border.color: del.active ? Config.ControlConfig.accent : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Config.ControlConfig.space2
                    spacing: Config.ControlConfig.space2

                    // Icon chip
                    Rectangle {
                        width: 26; height: 26
                        radius: Config.ControlConfig.radiusPill
                        anchors.verticalCenter: parent.verticalCenter
                        color: (del.active || navMa.containsMouse)
                               ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.16)
                               : Config.ThemeConfig.tint(Config.ThemeConfig.colors.surfaceContainer, 0.5)
                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            font.family: Config.ControlConfig.fontNerd
                            font.pixelSize: 13
                            color: (del.active || navMa.containsMouse) ? Config.ControlConfig.accent
                                                                       : Config.ThemeConfig.colors.textDim
                        }
                    }

                    Text {
                        visible: !Config.UIScale.compact
                        text: modelData.label
                        font.family: Config.ControlConfig.fontSans
                        font.pixelSize: 11
                        font.bold: del.active
                        font.letterSpacing: 0.6
                        anchors.verticalCenter: parent.verticalCenter
                        color: (del.active || navMa.containsMouse) ? Config.ControlConfig.accent
                                                                   : Config.ThemeConfig.colors.textDim
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                // Active dot (right edge) — visible in both rail widths
                Rectangle {
                    visible: del.active
                    anchors.right: parent.right
                    anchors.rightMargin: Config.ControlConfig.space2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5; height: 5; radius: 2.5
                    color: Config.ControlConfig.accent
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

    // Footer slot — pinned to the bottom; empty (0-height) unless populated.
    Column {
        id: footerSlot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Config.ControlConfig.space2
        spacing: 0
    }
}
