// =============================================================================
// settings/config/ThemePresets.qml
// Curated theme presets — views over the canonical seed
// =============================================================================
//
// This singleton holds the token bundles for the 7 curated presets.
// ThemeService, ThemeModule, and ThemePresetCard all read from here. The
// CANONICAL seed — "OLED Pure Black" — is shared/theme-core.mjs
// DEFAULT_BUNDLE (synced to ../lib/theme-core.mjs; the VFS cannot cross
// config roots, hence the sync): the preset entry below DERIVES from it
// rather than restating it (P1.9 — the two copies used to diverge).
// The other five presets are defined here and nowhere else.
//
// The canonical color tokens (Tier 1 structural + Tier 2 accents):
//   background, surface, surfaceVariant, surfaceContainer,
//   text, textDim, border, outline, outlineVariant,
//   primary, secondary, accent, success, warning, error, info
//
// =============================================================================

pragma Singleton
import QtQuick
import "../lib/theme-core.mjs" as ThemeCore

QtObject {
    id: presetRoot

    // =========================================================================
    // PRESET PALETTE TABLE — full token bundles for all 6 curated themes
    // =========================================================================

    readonly property var palettes: ({
        // THE seed — one definition, shared/theme-core.mjs (see header).
        "OLED Pure Black": ThemeCore.DEFAULT_BUNDLE,
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
        },
        // P6: the glyph identity ramp — "black, white dots, one red". Strict
        // monochrome ramp + the single red; semantics collapse into it (error
        // IS the red, success/warning/info read as ramp greys). Stored at the
        // true glyph values; clampOLED v2 tones what exceeds the caps (text,
        // outline) at apply time, like every other preset.
        "Glyph": {
            background: "#000000", surface: "#0e0e0e", surfaceVariant: "#1a1a1a",
            surfaceContainer: "#1a1a1a", text: "#f2f2f2", textDim: "#8c8c8c",
            border: "#2a2a2a", outline: "#4a4a4a", outlineVariant: "#1a1a1a",
            primary: "#d71921", secondary: "#8c8c8c", accent: "#d71921",
            success: "#8c8c8c", warning: "#8c8c8c", error: "#d71921", info: "#8c8c8c"
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
        "Dracula",
        "Glyph"
    ]
}
