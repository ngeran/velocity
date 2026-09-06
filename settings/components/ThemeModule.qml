// =============================================================================
// settings/components/ThemeModule.qml — Unified Theme Control Panel (no-scroll)
// =============================================================================
// One screen, no scrolling.
//
// Layout (canvas ≈ 1052×592 on a 4K display):
//   ┌─ HEADER: [OLED] toggle │ spectrum skyline (no theme name — the      ┐
//   │                          active card already marks it ✓)            │
//   ├──────────────────────────────────────────────────────────────────── ┤ ← thin border
//   │ CURATED PRESETS (2×3)   ││  MANUAL EDITOR                          │
//   │  small preset cards     ││  token grid + actions + save row        │
//   │ ────────────────        ││                                          │
//   │ CUSTOM (n/5) — same    ││                                          │
//   │  preset cards + EDIT ✕ ││                                          │
//   └──────────────────────────┴──────────────────────────────────────────┘
//               ↑ thin vertical border separates the two sections
//
// Header is a slim pure-black strip (32px): the bracket-style "[ OLED ● ]"
// toggle and a static spectrum "skyline" whose bar heights are set by token
// tier (structural low, semantic mid, accent tall). The active theme's NAME
// used to be shown here too — dropped as redundant (the active card in the
// grid carries ✓ + accent border + bold name). It was a 64px identity card
// before that.
//
// Curated is a narrow 2×3 grid of compact 148×56 pure-black cards, sized to
// their natural footprint (not stretched) so the MANUAL EDITOR gets the
// width it needs for its 3-column token grid. CUSTOM palettes (user-saved,
// max 5) live DIRECTLY UNDER the curated grid as the SAME cards (ThemePre-
// setCard with a paletteOverride) plus always-visible EDIT / ✕ corner
// actions — they are themes you apply, so they group with the presets, not
// with the editor that builds them (they used to be chips at the bottom of
// the editor). All 5 fit a ~520px-tall panel; shorter panels clamp by
// visibility (wifi-list pattern: delegates stay alive, footer counts the
// clipped remainder).
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services
import "." as Components

Item {
    id: root

    // -------------------------------------------------------------------------
    // STATE (bound to Config.ThemeConfig.metadata → reactive)
    // -------------------------------------------------------------------------
    property string currentTheme:     Config.ThemeConfig.metadata.name || "OLED Pure Black"
    property bool   oledClampEnabled: Config.ThemeConfig.metadata.oledClamp || false

    readonly property var extendedThemes: Config.ThemePresets.paletteNames

    // 16 palette tokens grouped by tier — drives the spectrum's bar
    // heights (structural low, semantic mid, accent tall), giving the
    // strip real shape instead of a flat block, with no hover required.
    readonly property var spectrumTokens: [
        { key: "background",       tier: "structural" },
        { key: "surface",          tier: "structural" },
        { key: "surfaceVariant",   tier: "structural" },
        { key: "surfaceContainer", tier: "structural" },
        { key: "text",             tier: "structural" },
        { key: "textDim",          tier: "structural" },
        { key: "border",           tier: "structural" },
        { key: "outline",          tier: "structural" },
        { key: "outlineVariant",   tier: "structural" },
        { key: "primary",          tier: "accent" },
        { key: "secondary",        tier: "accent" },
        { key: "accent",           tier: "accent" },
        { key: "success",          tier: "semantic" },
        { key: "warning",          tier: "semantic" },
        { key: "error",            tier: "semantic" },
        { key: "info",             tier: "semantic" }
    ]

    // Unique palette colors — first occurrence of each color value, so the
    // strip shows one swatch per DISTINCT color. Lunar has duplicates
    // (background/surface/surfaceVariant/surfaceContainer are all #000000,
    // secondary==accent, success==warning); this collapses them. Recomputes
    // when Config.ThemeConfig.colors changes (live with the theme).
    readonly property var uniqueSpectrumColors: {
        var seen = {}, out = []
        var cols = Config.ThemeConfig.colors
        for (var i = 0; i < root.spectrumTokens.length; i++) {
            var c = cols[root.spectrumTokens[i].key]
            if (c && !seen[c]) { seen[c] = true; out.push({ key: root.spectrumTokens[i].key, color: c, tier: root.spectrumTokens[i].tier }) }
        }
        return out
    }

    // Grid-row capacity of the custom viewport (56px cards + 8px gap, two
    // per row — 5 saved palettes = 3 rows). Cards are clamped by VISIBILITY,
    // never by slicing the model — same rationale as the wifi list (fresh
    // arrays destroy delegates mid-interaction).
    readonly property int customCapacityRows: Math.max(1, Math.floor((customViewport.height + 8) / 64))

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // =====================================================================
        // 1. HEADER — slim strip (32px): [ OLED ● ] toggle + the spectrum
        //    skyline. The theme NAME used to live here too — redundant: the
        //    active card in the grid already carries ✓ + accent border +
        //    bold name. Was a 64px identity card before that.
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: "#000000"
            border.color: Config.ThemeConfig.colors.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                // Bracket-style OLED clamp toggle — terminal flag, not a
                // settings row.
                Row {
                    spacing: 4

                    Text {
                        text: "["
                        font.pixelSize: 9
                        font.family: Config.SettingsConfig.fontFamily
                        color: Config.ThemeConfig.colors.textDim
                    }
                    Text {
                        text: "OLED"
                        font.pixelSize: 9; font.bold: true
                        font.family: Config.SettingsConfig.fontFamily
                        color: root.oledClampEnabled ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim
                    }
                    Rectangle {
                        width: 6; height: 6
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.oledClampEnabled ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim
                    }
                    Text {
                        text: "]"
                        font.pixelSize: 9
                        font.family: Config.SettingsConfig.fontFamily
                        color: Config.ThemeConfig.colors.textDim
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.ThemeService.setOledClamp(!root.oledClampEnabled)
                    }
                }

                // ── Divider ──
                Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: Config.ThemeConfig.colors.outlineVariant }

                // ── Spectrum skyline — a PLAIN fillWidth Rectangle (NOT a
                //    nested RowLayout: a nested layout whose children have no
                //    intrinsic width collapses to a right-edge sliver). Plain
                //    items stretch reliably via fillWidth. The bars are
                //    positioned explicitly, so neither the container nor the
                //    bars rely on per-item Layout.fillWidth. Each bar is
                //    outlined so the pure-black structural tokens
                //    (background/surface/… = #000000 in Lunar) stay visible
                //    against the pure-black header.
                Rectangle {
                    id: spectrumArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"
                    clip: true

                    Repeater {
                        model: root.uniqueSpectrumColors
                        delegate: Rectangle {
                            // Skyline bar — one per unique color, bottom-aligned,
                            // height by token tier (structural low, semantic mid,
                            // accent tall) so the strip has real shape.
                            x: index * (parent.width / root.uniqueSpectrumColors.length)
                            width: Math.max(6, parent.width / root.uniqueSpectrumColors.length - 8)
                            height: modelData.tier === "accent"   ? parent.height - 2
                                  : modelData.tier === "semantic" ? parent.height - 6
                                                                  : parent.height - 10
                            anchors.bottom: parent.bottom
                            color: modelData.color
                            border.color: Config.ThemeConfig.colors.outline
                            border.width: 1
                        }
                    }
                }
            }
        }

        // ── Thin border: header / main ──
        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

        // =====================================================================
        // 2 + 3. MAIN — CURATED (2×3)  │ thin vertical border │  MANUAL
        // =====================================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            // ── CURATED PRESETS (2×3 grid of the new compact, pure-black
            //    cards — sized to their natural footprint rather than
            //    stretched, so the grid stays tight at the top and the
            //    remaining space below reads as intentional whitespace,
            //    consistent with the OLED/no-filled-bars aesthetic). ──
            ColumnLayout {
                Layout.preferredWidth: 306     // 2 × 148 + 10px gap — real minimum, no slack
                Layout.fillHeight: true
                spacing: 6

                Text {
                    text: "CURATED PRESETS"
                    font.pixelSize: 9; font.bold: true; font.letterSpacing: 1
                    font.family: Config.SettingsConfig.fontFamily
                    color: Config.ThemeConfig.colors.text
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 8
                    columnSpacing: 10

                    Repeater {
                        model: root.extendedThemes
                        delegate: Components.ThemePresetCard {
                            themeName: modelData
                            isActive: root.currentTheme === modelData
                            onClicked: Services.ThemeService.applyPreset(modelData, root.oledClampEnabled)
                        }
                    }
                }

                // ── CUSTOM — user-saved palettes (max 5), grouped with the
                //    presets they sit beside. They used to be chips at the
                //    bottom of the MANUAL EDITOR (44px name elide!) — wrong
                //    column: these are themes you APPLY, not editor state. ──
                Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "CUSTOM"
                        font.pixelSize: 9; font.bold: true; font.letterSpacing: 1
                        font.family: Config.SettingsConfig.fontFamily
                        color: Config.ThemeConfig.colors.text
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: (Services.ThemeService.customThemes || []).length + "/5"
                        font.pixelSize: 8; font.bold: true
                        font.family: Config.SettingsConfig.fontFamily
                        color: Config.ThemeConfig.colors.textDim
                    }
                }

                // Card-grid viewport — custom palettes render as REAL
                // ThemePresetCards (same anatomy as curated: name, 12-swatch
                // strip, accent border + left bar when active) plus the
                // always-visible EDIT / ✕ corner actions. Clamped by
                // visibility to the rows that fit; footer counts the rest.
                Item {
                    id: customViewport
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    GridLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        columns: 2
                        rowSpacing: 8
                        columnSpacing: 10

                        Repeater {
                            model: Services.ThemeService.customThemes || []
                            delegate: Components.ThemePresetCard {
                                themeName: modelData.name
                                paletteOverride: modelData.colors
                                isActive: root.currentTheme === modelData.name
                                showActions: true
                                visible: Math.floor(index / 2) < root.customCapacityRows
                                onClicked: Services.ThemeService.applyCustomTheme(modelData.name)
                                // EDIT — apply live + pre-fill the save field
                                // so the next SAVE updates in place.
                                onEditClicked: {
                                    Services.ThemeService.applyCustomTheme(modelData.name)
                                    manualEditor.prefillSchemeName(modelData.name)
                                }
                                onDeleteClicked: Services.ThemeService.deleteCustomTheme(modelData.name)
                            }
                        }
                    }

                    // Empty state — nothing saved yet
                    Text {
                        anchors.centerIn: parent
                        visible: (Services.ThemeService.customThemes || []).length === 0
                        text: "// none saved — tweak tokens in the editor, then SAVE"
                        font.pixelSize: 8
                        font.family: Config.SettingsConfig.fontFamily
                        color: Config.ThemeConfig.colors.textDim
                    }
                }

                // Honest clamp footer (wifi-list pattern)
                Text {
                    Layout.fillWidth: true
                    readonly property int hidden: (Services.ThemeService.customThemes || []).length
                                                 - Math.min((Services.ThemeService.customThemes || []).length,
                                                            root.customCapacityRows * 2)
                    visible: hidden > 0
                    text: "+ " + hidden + " more not shown"
                    font.pixelSize: 8
                    font.family: Config.SettingsConfig.fontFamily
                    color: Config.ThemeConfig.colors.textDim
                    elide: Text.ElideRight
                }
            }

            // ── Thin vertical border: curated / manual ──
            Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: Config.ThemeConfig.colors.outlineVariant }

            // ── MANUAL EDITOR (fills the rest — token grid now fits) ──
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                Text {
                    text: "MANUAL EDITOR"
                    font.pixelSize: 9; font.bold: true; font.letterSpacing: 1
                    font.family: Config.SettingsConfig.fontFamily
                    color: Config.ThemeConfig.colors.text
                }

                Components.ManualThemeEditor {
                    id: manualEditor
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }
}
