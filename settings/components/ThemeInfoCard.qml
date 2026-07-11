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
    border.color: Config.ThemeConfig.colors.border
    border.width: 1
    radius:       0 // Hard sharp corners asset enforcement

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
            color:               Config.ThemeConfig.colors.textDim
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

                // Monospace accent baseline border line block matrix
                Rectangle {
                    anchors {
                        left:   parent.left
                        right:  parent.right
                        bottom: parent.bottom
                        bottomMargin: -4
                    }
                    height: 1
                    color:  root.primaryColor
                    radius: Config.SettingsConfig.radiusMd
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
