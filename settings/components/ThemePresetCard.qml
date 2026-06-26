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
        // Derive preview colors from ThemePresets (single source of truth)
        var palette = Config.ThemePresets.getPalette(name);
        if (!palette) {
            // Fallback to OLED Pure Black if theme not found
            palette = Config.ThemePresets.getPalette("OLED Pure Black");
        }

        // Map the full 17-token palette to the simplified format used by the card
        return {
            bg: palette.background,
            accent: palette.secondary,
            surface: palette.surfaceContainer,
            text: palette.text,
            swatches: [
                palette.background,
                palette.secondary,
                palette.primary,
                palette.text
            ]
        };
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
            color:           isActive ? Config.ThemeConfig.colors.text : themeColors.text
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
                    border.color: Config.ThemeConfig.colors.border
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
        color:        Config.ThemeConfig.colors.primary
        opacity:      interactiveClickArea.pressed ? 0.04 : (interactiveClickArea.containsMouse ? 0.02 : 0.0)
        radius:       0

        Behavior on opacity {
            NumberAnimation { duration: 50; easing.type: Easing.OutQuad }
        }
    }
}
