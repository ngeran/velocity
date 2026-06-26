// =============================================================================
// settings/config/ThemePresets.qml
// Single Source of Truth for All Theme Palettes
// =============================================================================
//
// This singleton contains the full 17-token bundle for all 6 curated presets.
// It is the canonical source of truth for theme palettes across the entire
// settings process. ThemeService, ThemeModule, and ThemePresetCard all read
// from here, eliminating palette drift and duplicate maintenance.
//
// The 17 canonical color tokens (Tier 1 structural + Tier 2 accents):
//   background, surface, surfaceVariant, surfaceContainer,
//   text, textDim, border, outline, outlineVariant,
//   primary, secondary, accent, success, warning, error, info
//
// These values MUST be kept in sync with ~/.local/bin/theme-switcher.
//
// =============================================================================

pragma Singleton
import QtQuick

QtObject {
    id: presetRoot

    // =========================================================================
    // PRESET PALETTE TABLE — full 17-token bundles for all 6 curated themes
    // =========================================================================

    readonly property var palettes: ({
        "OLED Pure Black": {
            background: "#000000", surface: "#000000", surfaceVariant: "#0a0a0a",
            surfaceContainer: "#111111", text: "#e0e0e0", textDim: "#808080",
            border: "#1a1a1a", outline: "#2a2a2a", outlineVariant: "#1a1a1a",
            primary: "#7c6bf0", secondary: "#00dce5", accent: "#f87171",
            success: "#34d399", warning: "#fbbf24", error: "#f87171", info: "#00dce5"
        },
        "Catppuccin Mocha": {
            background: "#1e1e2e", surface: "#181825", surfaceVariant: "#313244",
            surfaceContainer: "#313244", text: "#cdd6f4", textDim: "#a6adc8",
            border: "#313244", outline: "#45475a", outlineVariant: "#181825",
            primary: "#cba6f7", secondary: "#89b4fa", accent: "#f5c2e7",
            success: "#a6e3a1", warning: "#f9e2af", error: "#f38ba8", info: "#89dceb"
        },
        "Tokyo Night": {
            background: "#1a1b26", surface: "#16161e", surfaceVariant: "#2f3549",
            surfaceContainer: "#2f3549", text: "#c0caf5", textDim: "#a9b1d6",
            border: "#292e42", outline: "#414868", outlineVariant: "#16161e",
            primary: "#7aa2f7", secondary: "#bb9af7", accent: "#e0af68",
            success: "#9ece6a", warning: "#e0af68", error: "#f7768e", info: "#7dcfff"
        },
        "Nord": {
            background: "#2e3440", surface: "#2e3440", surfaceVariant: "#3b4252",
            surfaceContainer: "#3b4252", text: "#eceff4", textDim: "#d8dee9",
            border: "#3b4252", outline: "#434c5e", outlineVariant: "#2e3440",
            primary: "#88c0d0", secondary: "#81a1c1", accent: "#bf616a",
            success: "#a3be8c", warning: "#ebcb8b", error: "#bf616a", info: "#8fbcbb"
        },
        "Gruvbox Dark": {
            background: "#282828", surface: "#1d2021", surfaceVariant: "#3c3836",
            surfaceContainer: "#3c3836", text: "#ebdbb2", textDim: "#d5c4a1",
            border: "#3c3836", outline: "#504945", outlineVariant: "#1d2021",
            primary: "#fabd2f", secondary: "#83a598", accent: "#fe8019",
            success: "#b8bb26", warning: "#fabd2f", error: "#fb4934", info: "#8ec07c"
        },
        "Dracula": {
            background: "#282a36", surface: "#21222c", surfaceVariant: "#44475a",
            surfaceContainer: "#44475a", text: "#f8f8f2", textDim: "#6272a4",
            border: "#44475a", outline: "#6272a4", outlineVariant: "#21222c",
            primary: "#bd93f9", secondary: "#8be9fd", accent: "#ff79c6",
            success: "#50fa7b", warning: "#f1fa8c", error: "#ff5555", info: "#8be9fd"
        }
    })

    // =========================================================================
    // CONVENIENCE ACCESSORS
    // =========================================================================

    function getPalette(name) {
        return presetRoot.palettes[name] || null
    }

    function hasPalette(name) {
        return name in presetRoot.palettes
    }

    readonly property var paletteNames: [
        "OLED Pure Black",
        "Catppuccin Mocha",
        "Tokyo Night",
        "Nord",
        "Gruvbox Dark",
        "Dracula"
    ]
}
