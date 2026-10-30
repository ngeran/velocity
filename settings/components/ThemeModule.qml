// =============================================================================
// settings/components/ThemeModule.qml — Unified Theme Control Panel (no-scroll)
// =============================================================================
// One screen, no scrolling.
//
// Layout (canvas ≈ 1052×592 on a 4K display):
//   ┌─ HEADER: OLED SAFE + FOLLOW WALLPAPER switches │ spectrum skyline   ┐
//   ├──────────────────────────────────────────────────────────────────── ┤ ← thin border
//   │ CURATED PRESETS (2×3)   ││  MANUAL EDITOR                          │
//   │  small preset cards     ││  token grid + actions + save row        │
//   │ ────────────────        ││                                          │
//   │ CUSTOM (scrolls) — same ││                                          │
//   │  preset cards + EDIT ✕ ││                                          │
//   └──────────────────────────┴──────────────────────────────────────────┘
//               ↑ thin vertical border separates the two sections
//
// Header is a slim pure-black strip (32px): the labelled OLED SAFE clamp
// switch (P5.1: on by default — absent key means true), the FOLLOW WALLPAPER
// switch (P5.3: matugen re-themes on every rotation; same
// SettingsConfigService key as the Wallpapers page's AUTO-THEME pill), and a
// spectrum "skyline" whose bar heights are set by token tier (structural
// low, semantic mid, accent tall). Decorative static strokes (header border,
// per-bar outlines) were removed in P5.4 — QD-OLED doctrine.
//
// Curated is a narrow 2×3 grid of compact 148×56 pure-black cards. CUSTOM
// palettes (user-saved, UNLIMITED since P5.4) live DIRECTLY UNDER the
// curated grid as the SAME cards (ThemePresetCard with a paletteOverride)
// plus always-visible EDIT / ✕ corner actions, in a scrolling lazy GridView.
// Hovering ANY card fades the live palette to that theme (ThemeService.
// previewTheme → ThemeConfig.previewColors cross-fade); leaving reverts;
// clicking commits through the real apply path.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services
import "." as Components

Item {
    id: root

    // A destroyed card never emits previewExited (hover state dies with the
    // MouseArea) — end any live preview when the module itself unloads, or
    // the palette would stay stuck on the last hovered theme.
    Component.onDestruction: Services.ThemeService.endPreview()

    // -------------------------------------------------------------------------
    // STATE (bound to Config.ThemeConfig.metadata → reactive)
    // -------------------------------------------------------------------------
    property string currentTheme:     Config.ThemeConfig.metadata.name || "OLED Pure Black"
    // P5.1: the clamp is ON by default — an absent key means true (migration
    // law; DEFAULT_METADATA agrees). Never `|| false` here: an undefined read
    // would render the toggle OFF and invite an unclamped apply.
    property bool   oledClampEnabled: Config.ThemeConfig.metadata.oledClamp !== false

    // The theme follows the wallpaper (matugen re-runs on every rotation) —
    // one owner: SettingsConfigService.matugenOnWallpaperChange, the same key
    // the Wallpapers page's AUTO-THEME pill flips.
    property bool followWallpaper: Services.SettingsConfigService.matugenOnWallpaperChange

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

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // =====================================================================
        // 1. HEADER — slim strip (32px): the OLED SAFE + FOLLOW WALLPAPER
        //    switches (labelled, P5.4/P5.3) + the spectrum skyline. The theme
        //    NAME used to live here too — redundant: the active card in the
        //    grid already carries ✓ + accent border + bold name. The header's
        //    border stroke and the skyline bars' 1px outlines were removed
        //    (P5.4: decorative static strokes = standing burn-in risk; the
        //    bars read by height + tier color alone).
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: "#000000"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 14

                // ── OLED SAFE — labelled ToggleSwitch (was the bracket-style
                //    "[ OLED ● ]" terminal flag). Toggling re-applies the live
                //    theme through ThemeService with the new clamp state.
                RowLayout {
                    spacing: 6
                    Text {
                        text: "OLED SAFE"
                        font.pixelSize: 9; font.bold: true; font.letterSpacing: 1
                        font.family: Config.SettingsConfig.fontFamily
                        color: root.oledClampEnabled ? Config.ThemeConfig.colors.text : Config.ThemeConfig.colors.textDim
                    }
                    ToggleSwitch {
                        checked: root.oledClampEnabled
                        onToggled: Services.ThemeService.setOledClamp(!root.oledClampEnabled)
                    }
                }

                // ── FOLLOW WALLPAPER (P5.3) — matugen re-themes from every
                //    wallpaper the rotation lands on. Same owner as the
                //    Wallpapers page's AUTO-THEME pill; always clamped (the
                //    apply path routes through clampOLED).
                RowLayout {
                    spacing: 6
                    Text {
                        text: "FOLLOW WALLPAPER"
                        font.pixelSize: 9; font.bold: true; font.letterSpacing: 1
                        font.family: Config.SettingsConfig.fontFamily
                        color: root.followWallpaper ? Config.ThemeConfig.colors.text : Config.ThemeConfig.colors.textDim
                    }
                    ToggleSwitch {
                        checked: root.followWallpaper
                        onToggled: Services.SettingsConfigService.setMatugenOnWallpaperChange(
                                       !Services.SettingsConfigService.matugenOnWallpaperChange)
                    }
                }

                // ── Divider ──
                Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: Config.ThemeConfig.colors.outlineVariant }

                // ── Spectrum skyline — a PLAIN fillWidth Rectangle (NOT a
                //    nested RowLayout: a nested layout whose children have no
                //    intrinsic width collapses to a right-edge sliver). Plain
                //    items stretch reliably via fillWidth. The bars are
                //    positioned explicitly, so neither the container nor the
                //    bars rely on per-item Layout.fillWidth.
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
                            onPreviewEntered: Services.ThemeService.previewTheme(
                                                  Config.ThemePresets.getPalette(modelData))
                            onPreviewExited: Services.ThemeService.endPreview()
                        }
                    }
                }

                // ── CUSTOM — user-saved palettes, grouped with the presets
                //    they sit beside. They used to be chips at the bottom of
                //    the MANUAL EDITOR (44px name elide!) — wrong column: these
                //    are themes you APPLY, not editor state. The old 5-entry
                //    cap (n/5 counter, visibility-clamped rows, hidden-count
                //    footer) is gone — the viewport SCROLLS (P5.4). ──
                Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

                Text {
                    text: "CUSTOM"
                    font.pixelSize: 9; font.bold: true; font.letterSpacing: 1
                    font.family: Config.SettingsConfig.fontFamily
                    color: Config.ThemeConfig.colors.text
                }

                // Card grid — custom palettes render as REAL ThemePresetCards
                // (same anatomy as curated: name, 12-swatch strip, contrast
                // badge, accent border + left bar when active) plus the
                // always-visible EDIT / ✕ corner actions. Lazy GridView with
                // a tuned cacheBuffer: 50+ saved palettes scroll without
                // materializing every delegate.
                GridView {
                    id: customGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    cellWidth: 153; cellHeight: 64
                    cacheBuffer: 320
                    boundsBehavior: Flickable.StopAtBounds
                    model: Services.ThemeService.customThemes || []

                    delegate: Components.ThemePresetCard {
                        width: customGrid.cellWidth - 5
                        height: customGrid.cellHeight - 8
                        themeName: modelData.name
                        paletteOverride: modelData.colors
                        isActive: root.currentTheme === modelData.name
                        showActions: true
                        onClicked: Services.ThemeService.applyCustomTheme(modelData.name)
                        onPreviewEntered: Services.ThemeService.previewTheme(modelData.colors)
                        onPreviewExited: Services.ThemeService.endPreview()
                        // EDIT — apply live + pre-fill the save field
                        // so the next SAVE updates in place.
                        onEditClicked: {
                            Services.ThemeService.applyCustomTheme(modelData.name)
                            manualEditor.prefillSchemeName(modelData.name)
                        }
                        onDeleteClicked: Services.ThemeService.deleteCustomTheme(modelData.name)
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

                // ── PORT (P5.5): export/import the live palette. Export is
                //    always the POST-clamp live palette; import validates,
                //    clamps, saves as a custom theme and applies. File path
                //    empty → ~/.cache/theme/export/<theme>.<ext>. ──
                ColumnLayout {
                    id: portSection
                    property string exportFmt: "json"
                    property string importPath: ""
                    Layout.fillWidth: true
                    spacing: 4

                    Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "PORT"
                            font.pixelSize: 9; font.bold: true; font.letterSpacing: 1
                            font.family: Config.SettingsConfig.fontFamily
                            color: Config.ThemeConfig.colors.textDim
                        }

                        // format pills — JSON | BASE16
                        Repeater {
                            model: [{ k: "json", label: "JSON" }, { k: "base16", label: "BASE16" }]
                            delegate: Text {
                                text: modelData.label
                                font.pixelSize: 8; font.bold: true
                                font.family: Config.SettingsConfig.fontFamily
                                color: portSection.exportFmt === modelData.k
                                       ? Config.ThemeConfig.colors.primary : Config.ThemeConfig.colors.textDim
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -3
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: portSection.exportFmt = modelData.k
                                }
                            }
                        }

                        Text {
                            text: "EXPORT ▸ FILE"
                            font.pixelSize: 8; font.bold: true
                            font.family: Config.SettingsConfig.fontFamily
                            color: Config.ThemeConfig.colors.secondary
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -3
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Services.ThemeService.exportToFile(portSection.exportFmt, portPathField.text)
                            }
                        }

                        Text {
                            text: "EXPORT ▸ CLIP"
                            font.pixelSize: 8; font.bold: true
                            font.family: Config.SettingsConfig.fontFamily
                            color: Config.ThemeConfig.colors.secondary
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -3
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Services.ThemeService.exportToClipboard(portSection.exportFmt)
                            }
                        }

                        Item { Layout.fillWidth: true }

                        TextInput {
                            id: portPathField
                            Layout.preferredWidth: 220
                            color: Config.ThemeConfig.colors.text
                            font.pixelSize: 8
                            font.family: Config.SettingsConfig.fontFamily
                            selectByMouse: true
                            clip: true
                            property string placeholder: "/path/to/theme.json|yaml (empty = default)"
                            Text {
                                visible: portPathField.text === "" && !portPathField.activeFocus
                                text: portPathField.placeholder
                                color: Config.ThemeConfig.colors.textDim
                                font.pixelSize: 8
                                font.family: Config.SettingsConfig.fontFamily
                            }
                        }

                        Text {
                            text: "IMPORT FILE"
                            font.pixelSize: 8; font.bold: true
                            font.family: Config.SettingsConfig.fontFamily
                            color: Config.ThemeConfig.colors.secondary
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -3
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Services.ThemeService.importFromPath(portPathField.text)
                            }
                        }

                        Text {
                            text: "IMPORT CLIP"
                            font.pixelSize: 8; font.bold: true
                            font.family: Config.SettingsConfig.fontFamily
                            color: Config.ThemeConfig.colors.secondary
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -3
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Services.ThemeService.importFromClipboard()
                            }
                        }
                    }

                    // outcome line — error tinted, success dim
                    Text {
                        visible: Services.ThemeService.portError !== "" || Services.ThemeService.portStatus !== ""
                        text: Services.ThemeService.portError !== ""
                              ? Services.ThemeService.portError : Services.ThemeService.portStatus
                        font.pixelSize: 8
                        font.family: Config.SettingsConfig.fontFamily
                        color: Services.ThemeService.portError !== ""
                               ? Config.ThemeConfig.colors.error : Config.ThemeConfig.colors.textDim
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
