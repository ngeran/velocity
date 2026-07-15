// =============================================================================
// settings/components/ThemeInfoCard.qml
// Active Theme Status & Metadata Display Panel
// =============================================================================

import QtQuick
import "../config" as Config

Rectangle {
    id: root

    // =========================================================================
    // CONSOLIDATED SINGLE-ALIAS REACTION PROPERTIES
    // =========================================================================
    readonly property string themeName:      Config.SharedState.themeName
    readonly property string themeAuthor:    Config.SharedState.themeAuthor
    readonly property bool   isOLED:         Config.SharedState.themeIsOLED
    readonly property color  primaryColor:   Config.SharedState.themePrimaryColor
    readonly property color  secondaryColor: Config.SharedState.themeSecondaryColor
    readonly property color  textColor:      Config.SharedState.themeTextColor

    // =========================================================================
    // PHYSICAL INTERFACE CONSTRAINTS (OLED SAFE / ULTRA LOW LUMINANCE)
    // =========================================================================
    width:        220
    height:       130
    color:        Config.ThemeConfig.colors.surfaceContainer
    border.color: root.isHovered ? root.primaryColor : Config.ThemeConfig.colors.border
    border.width: 1
    radius:       0 // Hard sharp corners asset enforcement

    property bool isHovered: false

    Behavior on border.color {
        ColorAnimation { duration: Config.SettingsConfig.animDurationSlow; easing.type: Easing.OutQuad }
    }

    // Faint accent top-edge highlight — same language as DashboardCard,
    // so this reads as part of the same card family, not a one-off box.
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 1
        color: root.primaryColor
        opacity: root.isHovered ? 0.55 : 0.12
        Behavior on opacity { NumberAnimation { duration: Config.SettingsConfig.animDurationSlow; easing.type: Easing.OutQuad } }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.isHovered = true
        onExited: root.isHovered = false
        cursorShape: Qt.ArrowCursor
    }

    Column {
        anchors {
            fill:    parent
            margins: 14
        }
        spacing: 8

        // Module Context Header Label Component
        Text {
            text:               "ACTIVE STATE INDEX"
            font.pixelSize:      8
            font.family: Config.SettingsConfig.fontFamily
            font.letterSpacing:  1.5
            font.bold:           true
            color:               root.primaryColor
            opacity:             0.6
        }

        // Target Identifier Variable Sub-block Container
        Column {
            spacing: 2

            Text {
                text:           root.themeName
                font.pixelSize: 14
                font.family: Config.SettingsConfig.fontFamily
                font.bold:      true
                color:          Config.ThemeConfig.colors.text

                // Accent underline beneath the theme name
                Rectangle {
                    anchors {
                        left:   parent.left
                        right:  parent.right
                        bottom: parent.bottom
                        bottomMargin: -4
                    }
                    height: 2
                    color:  root.primaryColor
                    radius: 0
                }
            }
        }

        // Structural Padding Component Block
        Item { width: 1; height: 4 }

        // Origin Metadata Trace Line Component
        Text {
            text:           "source: " + root.themeAuthor
            font.pixelSize: 9
            font.family: Config.SettingsConfig.fontFamily
            color:          Config.ThemeConfig.colors.textDim
        }

        // Color Space Alignment Calibration Preview Strip Layout
        Row {
            spacing: 6

            Rectangle {
                width:        16
                height:       16
                color:        root.primaryColor
                border.color: Config.ThemeConfig.colors.border
                border.width: 1
                radius:       0
            }

            Rectangle {
                width:        16
                height:       16
                color:        root.secondaryColor
                border.color: Config.ThemeConfig.colors.border
                border.width: 1
                radius:       0
            }

            Rectangle {
                width:        16
                height:       16
                color:        root.textColor
                border.color: Config.ThemeConfig.colors.border
                border.width: 1
                radius:       0
            }

            // OLED Protection State Metadata Verification Token Badge Flag
            Rectangle {
                visible:      root.isOLED
                width:        42
                height:       16
                color:        "transparent"
                border.color: root.secondaryColor
                border.width: 1
                radius:       0

                Text {
                    anchors.centerIn: parent
                    text:            "OLED"
                    font.pixelSize:  8
                    font.family: Config.SettingsConfig.fontFamily
                    font.bold:       true
                    color:           root.secondaryColor
                    font.letterSpacing: 0.5
                }
            }
        }
    }
}
