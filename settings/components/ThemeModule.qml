// =============================================================================
// settings/components/ThemeModule.qml — Unified Theme Control Panel (no-scroll)
// =============================================================================
// One screen, no scrolling.
//
// Layout (canvas ≈ 1052×592 on a 4K display):
//   ┌─ HEADER: name/source/[OLED] toggle │ spectrum skyline ──────────────┐
//   ├──────────────────────────────────────────────────────────────────── ┤ ← thin border
//   │ CURATED PRESETS (2×3)   ││  MANUAL EDITOR                          │
//   │  small preset cards     ││  token grid + actions + save/schemes    │
//   └──────────────────────────┴──────────────────────────────────────────┘
//               ↑ thin vertical border separates the two sections
//
// Header is a single pure-black panel (was two separate bordered cards):
// identity + a bracket-style "[ OLED ● ]" toggle on the left, a static
// spectrum "skyline" on the right whose bar heights are set by token tier
// (structural low, semantic mid, accent tall) — no hover state needed.
// Its height (64px) matches the curated preset cards below it so the whole
// screen reads on one consistent scale.
//
// Curated is a narrow 2×3 grid of compact 148×64 pure-black cards, sized to
// their natural footprint (not stretched) so the MANUAL EDITOR gets the
// width it needs for its 3-column token grid.
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
            if (c && !seen[c]) { seen[c] = true; out.push({ key: root.spectrumTokens[i].key, color: c }) }
        }
        return out
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // =====================================================================
        // 1. HEADER — single merged panel: identity + bracket toggle on the
        //    left, spectrum skyline on the right. One card, one hairline
        //    divider, no hover states. Height matches the curated preset
        //    card (64px) so the whole screen reads on one consistent scale.
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            color: "#000000"
            border.color: Config.ThemeConfig.colors.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 16

                // ── Identity block ──
                ColumnLayout {
                    Layout.preferredWidth: 190
                    Layout.maximumWidth: 190   // PIN it — preferredWidth alone is just a
                                               // preference; without a cap the RowLayout
                                               // floats this column wide and starves the
                                               // fillWidth spectrum to ~1px.
                    Layout.fillHeight: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: root.currentTheme
                        font.pixelSize: 15; font.bold: true
                        font.family: Config.SettingsConfig.fontFamily
                        color: Config.ThemeConfig.colors.text
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "source: " + (Config.ThemeConfig.metadata.source || "—")
                        font.pixelSize: 8
                        font.family: Config.SettingsConfig.fontFamily
                        color: Config.ThemeConfig.colors.textDim
                        elide: Text.ElideRight
                    }

                    Item { Layout.fillHeight: true }

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
                }

                // ── Divider ──
                Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: Config.ThemeConfig.colors.outlineVariant }

                // ── Spectrum skyline — a PLAIN fillWidth Rectangle (NOT a
                //    nested RowLayout: a nested layout whose children have no
                //    intrinsic width collapses to a right-edge sliver — that's
                //    what was squeezing the palette past the theme name). Plain
                //    items stretch reliably via fillWidth. The 16 bars are
                //    positioned explicitly from parent.width/16, so neither the
                //    container nor the bars rely on per-item Layout.fillWidth.
                //    Each bar is outlined so the pure-black structural tokens
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
                            // Small even squares (one per unique color),
                            // distributed across the width, vertically centered.
                            x: index * (parent.width / root.uniqueSpectrumColors.length)
                            width: 20
                            height: 20
                            y: (parent.height - height) / 2
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
                spacing: 8

                Text {
                    text: "CURATED PRESETS"
                    font.pixelSize: 9; font.bold: true; font.letterSpacing: 1
                    font.family: Config.SettingsConfig.fontFamily
                    color: Config.ThemeConfig.colors.text
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 10
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

                Item { Layout.fillHeight: true }
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
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }
}
