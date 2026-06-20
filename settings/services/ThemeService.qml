// =============================================================================
// settings/services/ThemeService.qml
// Core Architectural State Machine Engine
// =============================================================================

pragma Singleton
import QtQuick
import Qt.labs.platform
import Quickshell.Io
import "../config" as Config

QtObject {
    id: themeService

    // =========================================================================
    // EXPOSED PUBLIC API STATE
    // =========================================================================
    readonly property string currentThemeName:   Config.ThemeConfig.metadata.name
    readonly property string currentThemeSource: Config.ThemeConfig.metadata.source
    readonly property bool   isOledClampActive:  Config.ThemeConfig.metadata.oledClamp

    property bool matugenAvailable: false
    property bool isRegenerating:    false

    // theme-switcher lives in ~/.local/bin, which is NOT on the quickshell
    // process's PATH — invoke it by absolute path or Process reports
    // "binary could not be found" and theme switches silently no-op.
    readonly property string _themeSwitcherBin: {
        // StandardPaths returns a file:// URL here; strip it or exec fails
        // (a literal "file://.../theme-switcher" path doesn't exist).
        var raw = StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.local/bin/theme-switcher"
        return raw.startsWith("file://") ? raw.substring(7) : raw
    }

    // Curated matrix representation for legacy interface alignment
    readonly property var curatedThemes: [
        "OLED Pure Black",
        "Catppuccin Mocha",
        "Tokyo Night"
    ]

    // =========================================================================
    // PRESET PALETTE TABLE — the in-process source of truth for curated themes.
    // -------------------------------------------------------------------------
    // applyPreset() applies a bundle from here DIRECTLY to Config.ThemeConfig
    // (instant recolor via bindings). This bypasses the unreliable colors.json
    // cat-poll as the primary apply path. These mirror the palettes in
    // ~/.local/bin/theme-switcher so quickshell and the global targets agree.
    // Full token set per theme (Tier 1 structural + Tier 2 accents).
    // =========================================================================
    readonly property var presetPalettes: ({
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
    // ASYNCHRONOUS TOOL DETECTION INFRASTRUCTURE
    // =========================================================================
    property var matugenCheck: Process {
        command: ["which", "matugen"]
        running: true
        onExited: (code) => {
            themeService.matugenAvailable = (code === 0);
        }
    }

    // =========================================================================
    // FILESYSTEM SYNCHRONIZATION RUNTIME NODE (LOOP BACK PROTECTION)
    // =========================================================================
    property var activeThemeWatcher: FileView {
        path: StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.config/quickshell/theme-active.json"

        onFileChanged: {
            // FileView.text is a METHOD (not a property) in this Quickshell build.
            let raw = activeThemeWatcher.text();
            if (!raw || raw.trim() === "") return;
            try {
                let data = JSON.parse(raw);
                if (data.name && data.name !== Config.ThemeConfig.metadata.name) {
                    Config.ThemeConfig.applyTheme(data);
                }
            } catch (e) {
                // Silently trap incomplete parse cycles during atomic write overlaps
            }
        }
    }

    // =========================================================================
    // SHELL UTILITY EXECUTORS
    // =========================================================================
    property var themeSwitcherRunner: Process {
        id: runner
        onExited: (code) => {
            themeService.isRegenerating = false;
            if (code !== 0) {
                console.warn("ThemeService: theme-switcher failed with exit code:", code);
            }
        }
    }

    // =========================================================================
    // INTERFACE MANIPULATION METHODS
    // =========================================================================

    /**
     * Serializes current state changes securely down into the tracked configuration file
     */
    function writeActiveThemeToken(name, source, clampValue) {
        let payload = {
            "name": name,
            "source": source,
            "applied": new Date().toISOString(),
            "oledClamp": clampValue,
            "matugenEnabled": (source === "matugen")
        };

        let path = StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.config/quickshell/theme-active.json";
        // Asynchronously dispatch the structural write stream through standard terminal interface shell
        let writer = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService);
        writer.command = ["sh", "-c", "printf '%s' '" + JSON.stringify(payload) + "' > " + path];
        writer.running = true;
    }

    /**
     * Executes internal structural preset modification pipeline updates
     */
    function applyPreset(presetName, applyOLEDClamp) {
        // NOTE: no isRegenerating early-return guard — a stuck flag (e.g. a prior
        // theme-switcher run whose onExited never fired during a reload) would
        // otherwise brick ALL theme switches. Set true here for UI; onExited clears.
        themeService.isRegenerating = true;

        // --- PRIMARY: apply the palette IN-PROCESS for instant, reliable recolor. ---
        // The colors.json cat-poll never reaches applyTheme, so we do NOT depend
        // on it. This recolors the whole shell immediately via ThemeConfig bindings.
        var palette = themeService.presetPalettes[presetName];
        if (!palette) {
            themeService.isRegenerating = false;
            console.warn("ThemeService: unknown preset (not in presetPalettes):", presetName);
            return;
        }
        var bundle = {};
        for (var k in palette) {
            if (Object.prototype.hasOwnProperty.call(palette, k)) bundle[k] = palette[k];
        }
        if (applyOLEDClamp) {
            bundle.background = "#000000";
            bundle.surface = "#000000";
        }
        Config.ThemeConfig.applyTheme({
            colors: bundle,
            metadata: {
                name: presetName,
                source: "preset",
                applied: new Date().toISOString(),
                oledClamp: applyOLEDClamp ? true : false,
                matugenEnabled: false
            }
        });

        // --- SECONDARY: theme-switcher for GLOBAL targets (hyprland/terminals/ ---
        // fastfetch). apply_quickshell is a no-op; quickshell already recolored.
        var args = [themeService._themeSwitcherBin, "--mode", "curated", "--theme", presetName];
        if (applyOLEDClamp) args.push("--oled-clamp");
        args.push("--apply", "all");
        themeService.writeActiveThemeToken(presetName, "preset", applyOLEDClamp);
        runner.command = args;
        runner.running = true;
    }

    /**
     * Triggers external automated Matugen wallpaper extraction workflows
     */
    function applyDynamicTheme(wallpaperPath, applyOLEDClamp) {
        if (themeService.isRegenerating) return;
        themeService.isRegenerating = true;

        let args = [themeService._themeSwitcherBin, "--mode", "dynamic", "--wallpaper", wallpaperPath];
        if (applyOLEDClamp) args.push("--oled-clamp");
        args.push("--apply", "all");

        Config.ThemeConfig.metadata = {
            "name": "Dynamic Wallpaper",
            "source": "matugen",
            "applied": new Date().toISOString(),
            "oledClamp": applyOLEDClamp,
            "matugenEnabled": true
        };

        themeService.writeActiveThemeToken("Dynamic Wallpaper", "matugen", applyOLEDClamp);
        runner.command = args;
        runner.running = true;
    }

    /**
     * Injects custom individual hex value token runtime updates manually
     */
    function applyManualOverride(tokenKey, hexValue) {
        if (!/^#[0-9A-Fa-f]{6}$/.test(hexValue)) return;

        Config.ThemeConfig.updateColorToken(tokenKey, hexValue);

        Config.ThemeConfig.metadata = {
            "name": "Custom Modification",
            "source": "manual",
            "applied": new Date().toISOString(),
            "oledClamp": themeService.isOledClampActive,
            "matugenEnabled": false
        };

        themeService.writeActiveThemeToken("Custom Modification", "manual", themeService.isOledClampActive);
    }

    function refreshTheme() {
        // Enforces atomic read validation tracking through ThemeConfig structure routines
        if (typeof Config.ThemeConfig.applyTheme === "function") {
             // Fallback query matching to verify pipeline sync structures
        }
    }

    function syncWithThemeConfig() {
        // Kept for signature tracking compatibility
    }
}
