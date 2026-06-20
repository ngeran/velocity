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

QtObject {
    // =========================================================================
    // DIMENSIONS
    // =========================================================================

    readonly property int sidebarWidth: 240
    readonly property int contentPadding: 24
    readonly property int navbarHeight: 64
    readonly property int cardPadding: 24

    // =========================================================================
    // COLORS - Modern Dark Theme
    // =========================================================================

    // Background colors
    readonly property color background: "#000000"
    readonly property color surface: "#131313"
    readonly property color surfaceLow: "#0A0A0A"
    readonly property color surfaceLowest: "#0E0E0E"
    readonly property color surfaceDim: "#131313"
    readonly property color surfaceBright: "#393939"
    readonly property color surfaceVariant: "#353535"
    readonly property color surfaceContainer: "#1F1F1F"
    readonly property color surfaceContainerLow: "#1B1B1B"
    readonly property color surfaceContainerHigh: "#2A2A2A"
    readonly property color surfaceContainerHighest: "#353535"

    // Primary colors
    readonly property color primary: "#FFFFFF"
    readonly property color colorOnPrimary: "#2F3131"
    readonly property color primaryContainer: "#E2E2E2"
    readonly property color colorOnPrimaryContainer: "#636565"
    readonly property color primaryFixed: "#E2E2E2"
    readonly property color primaryFixedDim: "#C6C6C7"

    // Secondary colors (accent blue)
    readonly property color secondary: "#A6C8FF"
    readonly property color colorOnSecondary: "#00315F"
    readonly property color secondaryContainer: "#3192FC"
    readonly property color colorOnSecondaryContainer: "#002A53"
    readonly property color secondaryFixed: "#D5E3FF"
    readonly property color secondaryFixedDim: "#A6C8FF"

    // Text colors
    readonly property color text: "#E2E2E2"
    readonly property color textDim: "#8E9192"
    readonly property color colorOnBackground: "#E2E2E2"
    readonly property color colorOnSurface: "#E2E2E2"
    readonly property color colorOnSurfaceVariant: "#C4C7C8"

    // Border & outline
    readonly property color border: "#262626"
    readonly property color borderDim: "#1A1A1A"
    readonly property color outline: "#8E9192"
    readonly property color outlineVariant: "#444748"

    // Semantic colors
    readonly property color success: "#4ADE80"
    readonly property color warning: "#FBBF24"
    readonly property color error: "#FFB4AB"
    readonly property color errorContainer: "#93000A"
    readonly property color info: "#A6C8FF"

    // Tertiary colors
    readonly property color tertiary: "#FFFFFF"
    readonly property color colorOnTertiary: "#313030"
    readonly property color tertiaryContainer: "#E5E2E1"
    readonly property color tertiaryFixed: "#E5E2E1"
    readonly property color tertiaryFixedDim: "#C8C6C5"
    readonly property color colorOnTertiaryContainer: "#656464"

    // Error colors
    readonly property color colorOnError: "#690005"
    readonly property color colorOnErrorContainer: "#FFDAD6"

    // Inverse colors
    readonly property color inverseSurface: "#E2E2E2"
    readonly property color inverseOnSurface: "#303030"
    readonly property color inversePrimary: "#5D5F5F"

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

    readonly property int radiusSm: 4
    readonly property int radiusMd: 8
    readonly property int radiusLg: 12
    readonly property int radiusXl: 16
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

    readonly property int animDurationFast: 100
    readonly property int animDurationNormal: 150
    readonly property int animDurationSlow: 250
    readonly property int animDurationSlower: 350
}
