// =============================================================================
// IdentityWidget.qml — Full-bleed identity card for bento dashboard
// VERSION: V2.0 — Item root, vertical layout, fills card height
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

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

        // ── HEADER ────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 12

            Text {
                text: "IDENTITY"
                color: Config.ThemeConfig.colors.textDim
                font.pixelSize: 9
                font.bold: true
                font.family: Config.SettingsConfig.fontFamily
                font.letterSpacing: 2.5
            }

            Item { Layout.fillWidth: true }

            // Online indicator
            Row {
                spacing: 5
                Rectangle {
                    width: 6; height: 6
                    radius: 0
                    color: identityRoot.online ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: identityRoot.online ? "ONLINE" : "OFFLINE"
                    color: identityRoot.online ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim
                    font.pixelSize: 8
                    font.bold: true
                    font.family: Config.SettingsConfig.fontFamily
                    font.letterSpacing: 1.5
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Thin rule
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Config.ThemeConfig.colors.outlineVariant
            Layout.bottomMargin: 14
        }

        // ── AVATAR + NAME ROW ─────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Layout.bottomMargin: 14

            // Avatar square — teal corner accent
            Item {
                width: 52; height: 52

                Rectangle {
                    anchors.fill: parent
                    color: Config.ThemeConfig.colors.surface
                    radius: 0
                    border.width: 1
                    border.color: Config.ThemeConfig.colors.outlineVariant
                }

                // Teal corner accent
                Rectangle {
                    width: 10; height: 2
                    color: Config.ThemeConfig.colors.secondary
                    anchors.top: parent.top
                    anchors.left: parent.left
                }
                Rectangle {
                    width: 2; height: 10
                    color: Config.ThemeConfig.colors.secondary
                    anchors.top: parent.top
                    anchors.left: parent.left
                }

                Text {
                    anchors.centerIn: parent
                    text: identityRoot.userName.substring(0, 2).toUpperCase()
                    color: Config.ThemeConfig.colors.secondary
                    font.pixelSize: 18
                    font.bold: true
                    font.family: Config.SettingsConfig.fontFamily
                }
            }

            // Name + role column
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: identityRoot.userName.toUpperCase()
                    color: Config.ThemeConfig.colors.primary
                    font.pixelSize: 18
                    font.bold: true
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

        // ── STAT ROWS ─────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { label: "HOST",  value: identityRoot.hostName },
                    { label: "SHELL", value: "ZSH" },
                    { label: "WM",    value: "HYPRLAND" }
                ]

                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: modelData.label
                        color: Config.ThemeConfig.colors.textDim
                        font.pixelSize: 8
                        font.family: Config.SettingsConfig.fontFamily
                        font.letterSpacing: 1.5
                        Layout.preferredWidth: 52
                    }

                    Rectangle {
                        width: 1; height: 10
                        color: Config.ThemeConfig.colors.outlineVariant
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "  " + modelData.value
                        color: Config.ThemeConfig.colors.primary
                        font.pixelSize: 9
                        font.bold: true
                        font.family: Config.SettingsConfig.fontFamily
                        font.letterSpacing: 0.5
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // ── STATUS BAR ────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Config.ThemeConfig.colors.outlineVariant
            Layout.bottomMargin: 10
        }

        Text {
            text: identityRoot.statusText
            color: Config.ThemeConfig.colors.secondary
            font.pixelSize: 8
            font.bold: true
            font.family: Config.SettingsConfig.fontFamily
            font.letterSpacing: 2.5
            opacity: 0.8
        }
    }
}
