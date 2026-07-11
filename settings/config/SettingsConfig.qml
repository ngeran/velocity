// =============================================================================
// SettingsConfig.qml — Modern Dashboard Design Tokens
// =============================================================================
//
// Modern glass-morphism design tokens matching the dashboard aesthetic.
// Deep blacks, subtle borders, and refined typography.
//
// =============================================================================

pragma Singleton

import QtQuick
import "./" as LocalConfig

QtObject {
    // =========================================================================
    // DIMENSIONS
    // =========================================================================

    readonly property int sidebarWidth: 240
    readonly property int contentPadding: 24
    readonly property int navbarHeight: 64
    readonly property int cardPadding: 24

    // Bar height (settings is a separate process and can't read BarConfig).
    // The dashboard card drops down and settles with its top at this offset.
    readonly property int barHeight: 26

    // =========================================================================
    // COLORS — Derive from ThemeConfig (single source of truth)
    // =========================================================================
    // NOTE: SettingsConfig colors are now reactive bindings to ThemeConfig.
    // This eliminates the dual palette problem — ThemeConfig is the SSOT,
    // SettingsConfig provides backwards-compatible aliases for existing components.

    // Background colors (mapped to ThemeConfig tokens)
    readonly property color background:           LocalConfig.ThemeConfig.colors.background
    readonly property color surface:              LocalConfig.ThemeConfig.colors.surface
    readonly property color surfaceLow:            LocalConfig.ThemeConfig.colors.surfaceVariant
    readonly property color surfaceLowest:        LocalConfig.ThemeConfig.colors.background
    readonly property color surfaceDim:           LocalConfig.ThemeConfig.colors.surface
    readonly property color surfaceBright:        LocalConfig.ThemeConfig.colors.surfaceVariant
    readonly property color surfaceVariant:       LocalConfig.ThemeConfig.colors.surfaceVariant
    readonly property color surfaceContainer:     LocalConfig.ThemeConfig.colors.surfaceContainer
    readonly property color surfaceContainerLow:   LocalConfig.ThemeConfig.colors.surfaceContainer
    readonly property color surfaceContainerHigh:  LocalConfig.ThemeConfig.colors.surfaceVariant
    readonly property color surfaceContainerHighest: LocalConfig.ThemeConfig.colors.surfaceVariant

    // Primary colors (mapped to text token)
    readonly property color primary:              LocalConfig.ThemeConfig.colors.text
    readonly property color colorOnPrimary:        LocalConfig.ThemeConfig.colors.background
    readonly property color primaryContainer:     LocalConfig.ThemeConfig.colors.surfaceContainer
    readonly property color colorOnPrimaryContainer: LocalConfig.ThemeConfig.colors.textDim
    readonly property color primaryFixed:         LocalConfig.ThemeConfig.colors.text
    readonly property color primaryFixedDim:      LocalConfig.ThemeConfig.colors.textDim

    // Secondary colors (mapped to secondary token)
    readonly property color secondary:             LocalConfig.ThemeConfig.colors.secondary
    readonly property color colorOnSecondary:       LocalConfig.ThemeConfig.colors.background
    readonly property color secondaryContainer:    LocalConfig.ThemeConfig.colors.secondary
    readonly property color colorOnSecondaryContainer: LocalConfig.ThemeConfig.colors.background
    readonly property color secondaryFixed:        LocalConfig.ThemeConfig.colors.secondary
    readonly property color secondaryFixedDim:     LocalConfig.ThemeConfig.colors.secondary

    // Text colors (mapped to ThemeConfig tokens)
    readonly property color text:                  LocalConfig.ThemeConfig.colors.text
    readonly property color textDim:               LocalConfig.ThemeConfig.colors.textDim
    readonly property color colorOnBackground:     LocalConfig.ThemeConfig.colors.text
    readonly property color colorOnSurface:         LocalConfig.ThemeConfig.colors.text
    readonly property color colorOnSurfaceVariant:  LocalConfig.ThemeConfig.colors.textDim

    // Border & outline (mapped to ThemeConfig tokens)
    readonly property color border:                LocalConfig.ThemeConfig.colors.border
    readonly property color borderDim:             LocalConfig.ThemeConfig.colors.outlineVariant
    readonly property color outline:               LocalConfig.ThemeConfig.colors.outline
    readonly property color outlineVariant:        LocalConfig.ThemeConfig.colors.outlineVariant

    // Semantic colors (mapped to ThemeConfig tokens)
    readonly property color success:               LocalConfig.ThemeConfig.colors.success
    readonly property color warning:               LocalConfig.ThemeConfig.colors.warning
    readonly property color error:                 LocalConfig.ThemeConfig.colors.error
    readonly property color errorContainer:        LocalConfig.ThemeConfig.colors.error
    readonly property color info:                  LocalConfig.ThemeConfig.colors.info

    // Tertiary colors (mapped to accent token)
    readonly property color tertiary:              LocalConfig.ThemeConfig.colors.accent
    readonly property color colorOnTertiary:        LocalConfig.ThemeConfig.colors.background
    readonly property color tertiaryContainer:     LocalConfig.ThemeConfig.colors.surfaceContainer
    readonly property color tertiaryFixed:         LocalConfig.ThemeConfig.colors.accent
    readonly property color tertiaryFixedDim:      LocalConfig.ThemeConfig.colors.accent
    readonly property color colorOnTertiaryContainer: LocalConfig.ThemeConfig.colors.textDim

    // Error colors (mapped to error token)
    readonly property color colorOnError:           LocalConfig.ThemeConfig.colors.background
    readonly property color colorOnErrorContainer:  LocalConfig.ThemeConfig.colors.error

    // Inverse colors (mapped to appropriate tokens)
    readonly property color inverseSurface:         LocalConfig.ThemeConfig.colors.text
    readonly property color inverseOnSurface:       LocalConfig.ThemeConfig.colors.surface
    readonly property color inversePrimary:         LocalConfig.ThemeConfig.colors.textDim

    // =========================================================================
    // TYPOGRAPHY - Modern Font Stack
    // =========================================================================

    readonly property string fontFamily: "Inter, JetBrains Mono, monospace"
    readonly property int fontSizeDisplay: 32
    readonly property int fontSizeHeadline: 24
    readonly property int fontSizeTitle: 18
    readonly property int fontSizeBody: 14
    readonly property int fontSizeLabel: 12
    readonly property int fontSizeSmall: 11

    // Font weights
    readonly property int fontWeightRegular: 400
    readonly property int fontWeightMedium: 500
    readonly property int fontWeightSemibold: 600
    readonly property int fontWeightBold: 700
    readonly property int fontWeightBlack: 900

    // =========================================================================
    // SPACING
    // =========================================================================

    readonly property int spacingXs: 4
    readonly property int spacingSm: 8
    readonly property int spacingMd: 16
    readonly property int spacingLg: 24
    readonly property int spacingXl: 32
    readonly property int spacing2Xl: 48

    // =========================================================================
    // BORDER RADIUS
    // =========================================================================

    // Corner radius — driven by SettingsConfigService.cornerRadius (set from the
    // Settings tab). Default 0 = OLED-sharp. radiusFull stays pill-shaped.
    property int cornerRadius: 0
    property int radiusSm: cornerRadius
    property int radiusMd: cornerRadius
    property int radiusLg: cornerRadius
    property int radiusXl: cornerRadius
    readonly property int radiusFull: 9999

    // =========================================================================
    // SHADOWS
    // =========================================================================

    readonly property int shadowSm: 2
    readonly property int shadowMd: 4
    readonly property int shadowLg: 8
    readonly property int shadowXl: 16

    // =========================================================================
    // ANIMATION
    // =========================================================================

    // Animation durations (ms) — scaled by animMultiplier, set by
    // SettingsConfigService from the Animation Speed preference (fast/normal/slow).
    property real animMultiplier: 1.0   // 0.5 fast · 1.0 normal · 1.7 slow
    property int animDurationFast: Math.round(100 * animMultiplier)
    property int animDurationNormal: Math.round(150 * animMultiplier)
    property int animDurationSlow: Math.round(250 * animMultiplier)
    property int animDurationSlower: Math.round(350 * animMultiplier)
}
