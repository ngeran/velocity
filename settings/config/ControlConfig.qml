// =============================================================================
// ControlConfig.qml — Terminal Command Dashboard design tokens
// =============================================================================
//
// Fixed "OBSIDIAN_CORE_OS" terminal aesthetic. The cyan accent (#2E90FA) and
// scanline are DELIBERATELY fixed and do NOT follow the active theme — only the
// structural chrome (background/text/border) reads from ThemeConfig so the panel
// stays consistent with the rest of the shell.
//
// Sections drive the side-nav + content view selection.
// =============================================================================

pragma Singleton

import QtQuick

QtObject {
    // --- Window ---
    readonly property int windowWidth: 680
    readonly property int windowHeight: 680

    // --- Fixed terminal accent (NOT themed) ---
    readonly property color accent: "#2E90FA"
    readonly property color accentDim: "#1c5fa8"
    readonly property color accentSoft: Qt.rgba(0.180, 0.564, 0.980, 0.15)

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

    // --- Console log colors by kind (accent/error fixed) ---
    readonly property color logInput: "#2E90FA"
    readonly property color logSuccess: "#4ade80"
    readonly property color logWarning: "#fbbf24"
    readonly property color logError: "#f87171"

    // --- Scanline overlay ---
    readonly property real scanlineOpacity: 0.05
    readonly property int scanlineSpacing: 3
}
