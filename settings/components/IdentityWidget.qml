// =============================================================================
// IdentityWidget.qml — Identity card for the dashboard bento grid
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "." as Components

Item {
    id: identityRoot

    property string userName:   "NIKOS"
    property string statusText: "CORE ACTIVE"
    property string hostName:   "obsidian"
    property string roleText:   "NETWORK ENGINEER"
    property bool   online:     true

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header + online indicator
        Item {
            Layout.fillWidth: true
            Layout.bottomMargin: 14
            height: 18

            Components.WidgetHeader {
                icon: "󰀄"
                label: "IDENTITY"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Rectangle {
                    width: 6; height: 6
                    color: identityRoot.online ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: identityRoot.online ? "ONLINE" : "OFFLINE"
                    color: identityRoot.online ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim
                    font.pixelSize: 8; font.bold: true
                    font.family: Config.SettingsConfig.fontFamily
                    font.letterSpacing: 1.5
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Avatar + name/role
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Layout.bottomMargin: 14

            Item {
                width: 48; height: 48
                Layout.alignment: Qt.AlignTop

                Rectangle {
                    anchors.fill: parent
                    color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.12)
                    border.width: 1
                    border.color: Config.ThemeConfig.colors.outlineVariant
                }
                Rectangle { width: 12; height: 2; color: Config.ThemeConfig.colors.secondary; anchors.top: parent.top; anchors.left: parent.left }
                Rectangle { width: 2; height: 12; color: Config.ThemeConfig.colors.secondary; anchors.top: parent.top; anchors.left: parent.left }

                Text {
                    anchors.centerIn: parent
                    text: identityRoot.userName.substring(0, 2).toUpperCase()
                    color: Config.ThemeConfig.colors.secondary
                    font.pixelSize: 18; font.bold: true
                    font.family: Config.SettingsConfig.fontFamily
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: identityRoot.userName.toUpperCase()
                    color: Config.ThemeConfig.colors.primary
                    font.pixelSize: 16; font.bold: true
                    font.family: Config.SettingsConfig.fontFamily
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Text {
                    text: identityRoot.roleText
                    color: Config.ThemeConfig.colors.textDim
                    font.pixelSize: 8
                    font.family: Config.SettingsConfig.fontFamily
                    font.letterSpacing: 1.5
                }
            }
        }

        // Stats
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [
                    { label: "HOST",  value: identityRoot.hostName },
                    { label: "SHELL", value: "ZSH" },
                    { label: "WM",    value: "HYPRLAND" }
                ]
                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: modelData.label
                        color: Config.ThemeConfig.colors.textDim
                        font.pixelSize: 8
                        font.family: Config.SettingsConfig.fontFamily
                        font.letterSpacing: 1.5
                        Layout.preferredWidth: 48
                    }
                    Text {
                        text: modelData.value
                        color: Config.ThemeConfig.colors.text
                        font.pixelSize: 9; font.bold: true
                        font.family: Config.SettingsConfig.fontFamily
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Status footer
        Text {
            text: identityRoot.statusText
            color: Config.ThemeConfig.colors.secondary
            font.pixelSize: 8; font.bold: true
            font.family: Config.SettingsConfig.fontFamily
            font.letterSpacing: 2.5
            opacity: 0.85
        }
    }
}
