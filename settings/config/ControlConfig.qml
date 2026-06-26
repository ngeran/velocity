// =============================================================================
// ControlConfig.qml — Terminal Command Dashboard design tokens
// =============================================================================
//
// "OBSIDIAN_CORE_OS" terminal aesthetic. The accent + log colors now follow the
// active theme (bound to the sibling ThemeConfig singleton — same pattern
// SharedState uses), so the control panel recolors with the rest of the shell.
// Only the scanline strength stays fixed. Structural chrome (background/text/
// border) already reads from ThemeConfig.
//
// Sections drive the side-nav + content view selection.
// =============================================================================

pragma Singleton

import QtQuick

QtObject {
    // --- Window ---
    readonly property int windowWidth: 680
    readonly property int windowHeight: 680

    // --- Terminal accent — follows the active theme (was a fixed #2E90FA) ---
    readonly property color accent:     ThemeConfig.colors.secondary
    readonly property color accentDim:  ThemeConfig.tint(ThemeConfig.colors.secondary, 0.6)
    readonly property color accentSoft: ThemeConfig.tint(ThemeConfig.colors.secondary, 0.15)

    // --- Typography ---
    readonly property string fontMono: "JetBrains Mono"
    readonly property int fontHeadline: 14
    readonly property int fontBody: 12
    readonly property int fontLabel: 11
    readonly property int fontSmall: 10
    readonly property int fontTiny: 9

    // --- Layout ---
    readonly property int appbarHeight: 48
    readonly property int sidenavWidth: 160
    readonly property int commandBarHeight: 52
    readonly property int statusCardHeight: 76
    readonly property int statusCardWidth: 190
    readonly property int padding: 16
    readonly property int radius: 4

    // --- Sections (side-nav model) ---
    // Nerd Font glyphs verified to render elsewhere in this config.
    readonly property var sections: [
        { key: "network",   label: "NETWORK",   icon: "󰖩" },
        { key: "bluetooth", label: "BLUETOOTH", icon: "󰂯" },
        { key: "audio",     label: "AUDIO",     icon: "󰕾" },
        { key: "power",     label: "POWER",     icon: "󰐦" },
        { key: "system",    label: "SYSTEM",    icon: "󰒋" }
    ]

    // --- Console log colors by kind (theme-aware) ---
    readonly property color logInput:   ThemeConfig.colors.secondary
    readonly property color logSuccess: ThemeConfig.colors.success
    readonly property color logWarning: ThemeConfig.colors.warning
    readonly property color logError:   ThemeConfig.colors.error

    // --- Scanline overlay ---
    readonly property real scanlineOpacity: 0.05
    readonly property int scanlineSpacing: 3
}
