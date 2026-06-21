// =============================================================================
// settings/components/ThemePresetCard.qml
// Redesigned System Theme Preset Card Element
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

Rectangle {
    id: root

    // =========================================================================
    // PUBLIC API PROPERTIES
    // =========================================================================
    property string themeName: ""
    property bool isActive: false
    signal clicked()

    // =========================================================================
    // RECONCILED PRESET COLOR MAP DICTIONARY
    // =========================================================================
    readonly property var themeColors: getThemeColors(themeName)

    function getThemeColors(name) {
        const matrix = {
            "OLED Pure Black": {
                bg:      "#000000",
                accent:  "#00dce5",
                surface: "#0a0a0a",
                text:    "#e0e0e0",
                swatches: ["#000000", "#00dce5", "#7c6bf0", "#e0e0e0"]
            },
            "Catppuccin Mocha": {
                bg:      "#1e1e2e",
                accent:  "#cba6f7",
                surface: "#313244",
                text:    "#cdd6f4",
                swatches: ["#1e1e2e", "#cba6f7", "#89b4fa", "#cdd6f4"]
            },
            "Tokyo Night": {
                bg:      "#1a1b26",
                accent:  "#7aa2f7",
                surface: "#16161e",
                text:    "#a9b1d6",
                swatches: ["#1a1b26", "#7aa2f7", "#bb9af7", "#a9b1d6"]
            },
            "Nord": {
                bg:      "#2e3440",
                accent:  "#88c0d0",
                surface: "#2e3440",
                text:    "#eceff4",
                swatches: ["#2e3440", "#88c0d0", "#81a1c1", "#eceff4"]
            },
            "Gruvbox Dark": {
                bg:      "#282828",
                accent:  "#fabd2f",
                surface: "#1d2021",
                text:    "#ebdbb2",
                swatches: ["#282828", "#fabd2f", "#83a598", "#ebdbb2"]
            },
            "Dracula": {
                bg:      "#282a36",
                accent:  "#bd93f9",
                surface: "#21222c",
                text:    "#f8f8f2",
                swatches: ["#282a36", "#bd93f9", "#8be9fd", "#f8f8f2"]
            }
        };
        // Safe structural fallback parsing configuration
        return matrix[name] !== undefined ? matrix[name] : matrix["OLED Pure Black"];
    }

    // =========================================================================
    // VISUAL ARCHITECTURE HIERARCHY
    // =========================================================================
    width:  160
    height: 90
    color:  themeColors.surface
    border.color: isActive ? themeColors.accent : Config.ThemeConfig.colors.border
    border.width: 1
    radius: 0 // Hard enforcement of sharp corners

    // Active status accent vertical indicator strip bar (left-aligned)
    Rectangle {
        id: activeIndicatorBar
        anchors {
            left:   parent.left
            top:    parent.top
            bottom: parent.bottom
        }
        width:   3
        color:   isActive ? themeColors.accent : "transparent"
        radius:  0
    }

    ColumnLayout {
        anchors {
            fill: parent
            leftMargin:  12
            rightMargin: 12
            topMargin:   10
            bottomMargin: 10
        }
        spacing: 6

        // Theme String Identification Label Node
        Text {
            Layout.fillWidth: true
            text:            root.themeName
            font.pixelSize:  12
            font.family:     "monospace"
            font.bold:       isActive
            color:           isActive ? "#ffffff" : themeColors.text
            elide:           Text.ElideRight
        }

        // Color Swatch Strip Layout Grid Component Block
        Row {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: root.themeColors.swatches
                delegate: Rectangle {
                    width:  14
                    height: 14
                    color:  modelData
                    border.color: "#1a1a1a"
                    border.width: 1
                    radius: 0
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Core Status Interactive Tag Row Module
        RowLayout {
            Layout.fillWidth: true

            Rectangle {
                id: tagWrapper
                visible: root.isActive
                Layout.preferredWidth:  statusLabel.implicitWidth + 8
                Layout.preferredHeight: 14
                color:        "transparent"
                border.color: themeColors.accent
                border.width: 1
                radius:       0

                Text {
                    id: statusLabel
                    anchors.centerIn: parent
                    text:            "ACTIVE"
                    font.pixelSize:  8
                    font.family:     "monospace"
                    font.letterSpacing: 1.0
                    color:           themeColors.accent
                }
            }

            // Consistent baseline alignment element spacer
            Item {
                visible: !root.isActive
                Layout.preferredHeight: 14
            }
        }
    }

    // =========================================================================
    // INTERACTION MOUSE HANDLING NODE LAYER
    // =========================================================================
    MouseArea {
        id: interactiveClickArea
        anchors.fill: parent
        cursorShape:  Qt.PointingHandCursor
        hoverEnabled: true
        onClicked:    root.clicked()
    }

    // Clean terminal press luminance modifier canvas overlay element
    Rectangle {
        anchors.fill: parent
        color:        "#ffffff"
        opacity:      interactiveClickArea.pressed ? 0.04 : (interactiveClickArea.containsMouse ? 0.02 : 0.0)
        radius:       0

        Behavior on opacity {
            NumberAnimation { duration: 50; easing.type: Easing.OutQuad }
        }
    }
}
