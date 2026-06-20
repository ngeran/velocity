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
    // TYPOGRAPHY / TEXT GRAPH SEMANTICS (RESOLVES PRIMARY COLLISION)
    // =========================================================================
    // Hard-pinned to pure white text styling for legacy prototype layout blocks:
    readonly property color primary:          "#ffffff"
    readonly property color textMuted:        Config.ThemeConfig.colors.textDim
    readonly property color textVariant:      Config.ThemeConfig.colors.text

    // =========================================================================
    // TIER 2 — ACCENT PIPELINE MAPPINGS (REACTIVE)
    // =========================================================================
    readonly property color accentCyan:  Config.ThemeConfig.colors.secondary
    readonly property color accentBlue:  Config.ThemeConfig.colors.info
    readonly property color accentWarn:  Config.ThemeConfig.colors.warning
    readonly property color accentErr:   Config.ThemeConfig.colors.error
}
