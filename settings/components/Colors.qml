// =============================================================================
// settings/components/Colors.qml
// Semantic Proxy Shim & Token Mapping Layer
//
// PURPOSE:
//   Acts as a backwards-compatible translation shim matching the flat
//   namespace requirements of existing legacy / prototype widgets. Maps
//   properties directly to the single source of truth (ThemeConfig) using
//   a single-level relative directory path lookup to avoid singleton bugs.
//
// CONSTRAINTS:
//   - pragma Singleton enforced.
//   - Pin Colors.primary explicitly to clear text vs. accent conflicts.
//   - Sharp corners (radius: 0) and monospace tracking inherited upstream.
// =============================================================================

pragma Singleton
import QtQuick
import "../config" as Config

QtObject {
    id: shim

    // =========================================================================
    // TIER 1 — STRUCTURAL TRANSLATIONS (REACTIVE)
    // =========================================================================
    readonly property color background:       Config.ThemeConfig.colors.background
    readonly property color surface:          Config.ThemeConfig.colors.surface
    readonly property color surfaceContainer: Config.ThemeConfig.colors.surfaceContainer
    readonly property color outline:          Config.ThemeConfig.colors.outline
    readonly property color outlineVariant:   Config.ThemeConfig.colors.outlineVariant
    readonly property color border:           Config.ThemeConfig.colors.border

    // =========================================================================
    // TYPOGRAPHY / TEXT GRAPH SEMANTICS
    // =========================================================================
    // Primary now binds to the canonical text token (strong text role)
    readonly property color primary:          Config.ThemeConfig.colors.text
    readonly property color textMuted:        Config.ThemeConfig.colors.textDim
    readonly property color textVariant:      Config.ThemeConfig.colors.text

    // =========================================================================
    // ACCENT COLORS (semantic mappings to ThemeConfig)
    // =========================================================================
    readonly property color secondary:  Config.ThemeConfig.colors.secondary
    readonly property color info:       Config.ThemeConfig.colors.info
    readonly property color warning:    Config.ThemeConfig.colors.warning
    readonly property color error:     Config.ThemeConfig.colors.error
}
