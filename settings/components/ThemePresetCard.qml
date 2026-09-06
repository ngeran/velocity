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
    // Full 17-token palette override — set for CUSTOM palettes (ThemeModule's
    // saved-theme grid): the card then previews the user's saved colors
    // instead of looking the name up in the curated preset table.
    property var paletteOverride: null
    // Show the always-visible EDIT / ✕ corner actions (custom palettes only).
    // When on, the active ✓ is suppressed — the accent border + left bar +
    // bold name already mark the active card, and the corner is needed for
    // the actions.
    property bool showActions: false
    // Overridable size — 148×56 is the compact curated-grid footprint
    // (ThemeModule). Pass these explicitly when a card should flex to
    // fill a GridLayout cell instead.
    property real cardWidth: 148
    property real cardHeight: 56
    signal clicked()
    signal editClicked()
    signal deleteClicked()

    // =========================================================================
    // RECONCILED PRESET COLOR MAP DICTIONARY
    // =========================================================================
    readonly property var themeColors: getThemeColors(themeName)

    function getThemeColors(name) {
        // Derive preview colors from the override if set (custom palettes),
        // else ThemePresets (single source of truth for curated themes)
        var palette = root.paletteOverride || Config.ThemePresets.getPalette(name);
        if (!palette) {
            // Fallback to OLED Pure Black if theme not found
            palette = Config.ThemePresets.getPalette("OLED Pure Black");
        }

        // Map the full 17-token palette to the simplified format used by the card
        // Swatches now show a representative set of 12 colors (up from 4)
        // giving a much better preview fidelity
        return {
            bg: palette.background,
            accent: palette.secondary,
            surface: palette.surfaceContainer,
            text: palette.text,
            swatches: [
                // Tier 1: Structural foundations
                palette.background,
                palette.surface,
                palette.surfaceVariant,
                palette.surfaceContainer,
                palette.text,
                palette.textDim,
                palette.border,
                palette.outline,
                palette.outlineVariant,
                // Tier 2: Accent fields
                palette.primary,
                palette.secondary,
                palette.accent
            ]
        };
    }

    // =========================================================================
    // VISUAL ARCHITECTURE HIERARCHY
    // =========================================================================
    implicitWidth:  cardWidth
    implicitHeight: cardHeight
    color:  "#000000"   // always pure OLED black — the preset's own surface
                         // color used to tint every card differently; the
                         // swatch strip is the only place palette color
                         // should show up now.
    border.color: isActive ? themeColors.accent : Config.ThemeConfig.colors.border
    border.width: isActive ? 2 : 1
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

    // Active checkmark — top-right flag on the currently-applied preset.
    // Suppressed on action cards (custom palettes): the corner hosts the
    // always-visible EDIT / ✕ there.
    Text {
        visible: root.isActive && !root.showActions
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 3
        anchors.rightMargin: 5
        text: "✓"
        font.family: Config.SettingsConfig.fontFamily
        font.pixelSize: 10
        font.bold: true
        color: themeColors.accent
    }

    ColumnLayout {
        anchors {
            fill: parent
            leftMargin:  10
            rightMargin: 10
            topMargin:   6
            bottomMargin: 6
        }
        spacing: 4

        // Theme String Identification Label Node
        Text {
            Layout.fillWidth: true
            text:            root.themeName
            font.pixelSize:  11
            font.family: Config.SettingsConfig.fontFamily
            font.bold:       isActive
            color:           isActive ? Config.ThemeConfig.colors.text : themeColors.text
            elide:           Text.ElideRight
        }

        Item { Layout.fillHeight: true }

        // Color Swatch Strip Layout Grid Component Block
        Row {
            Layout.fillWidth: true
            spacing: 2

            Repeater {
                model: root.themeColors.swatches
                delegate: Rectangle {
                    width:  7
                    height: 10
                    color:  modelData
                    border.color: Config.ThemeConfig.colors.border
                    border.width: 1
                    radius: Config.SettingsConfig.radiusMd
                }
            }
        }
    }

    // =========================================================================
    // INTERACTION MOUSE HANDLING NODE LAYER
    // =========================================================================
    // NOTE: no focus/Keys keyboard handling — every card used to declare
    // focus:true, so the LAST card created (Dracula) permanently held
    // activeFocus and rendered a second 2px primary border alongside the
    // actually-active preset. The shell does no keyboard navigation here.
    MouseArea {
        id: interactiveClickArea
        anchors.fill: parent
        cursorShape:  Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: root.clicked()
    }

    // Clean terminal press luminance modifier canvas overlay element
    Rectangle {
        anchors.fill: parent
        color:        Config.ThemeConfig.colors.primary
        opacity:      interactiveClickArea.pressed ? 0.04 : (interactiveClickArea.containsMouse ? 0.02 : 0.0)
        radius:       0

        Behavior on opacity {
            NumberAnimation { duration: Config.SettingsConfig.animDurationFast; easing.type: Easing.OutQuad }
        }
    }

    // =========================================================================
    // CORNER ACTIONS — always visible, custom palettes only (showActions).
    // Declared LAST so these MouseAreas sit above the card-wide click area.
    // EDIT emits editClicked() (caller loads the palette into the manual
    // editor); ✕ emits deleteClicked().
    // =========================================================================
    Row {
        visible: root.showActions
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 3
        anchors.rightMargin: 5
        spacing: 6

        Text {
            text: "EDIT"
            font.family: Config.SettingsConfig.fontFamily
            font.pixelSize: 8
            font.bold: true
            color: cardEditMA.containsMouse ? Config.ThemeConfig.colors.primary : Config.ThemeConfig.colors.textDim
            Behavior on color { ColorAnimation { duration: 120 } }
            MouseArea {
                id: cardEditMA
                anchors.fill: parent
                anchors.margins: -3   // a little slack around 8px type
                cursorShape: Qt.PointingHandCursor
                onClicked: root.editClicked()
            }
        }

        Text {
            text: "✕"
            font.family: Config.SettingsConfig.fontFamily
            font.pixelSize: 10
            color: cardDelMA.containsMouse ? Config.ThemeConfig.colors.error : Config.ThemeConfig.colors.textDim
            Behavior on color { ColorAnimation { duration: 120 } }
            MouseArea {
                id: cardDelMA
                anchors.fill: parent
                anchors.margins: -3
                cursorShape: Qt.PointingHandCursor
                onClicked: root.deleteClicked()
            }
        }
    }
}
