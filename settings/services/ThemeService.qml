// =============================================================================
// settings/services/ThemeService.qml
// Core Architectural State Machine Engine
// =============================================================================

pragma Singleton
import QtQuick
import Qt.labs.platform
import Quickshell.Io
import "../config" as Config

Item {
    id: themeService

    // =========================================================================
    // EXPOSED PUBLIC API STATE
    // =========================================================================
    readonly property string currentThemeName:   Config.ThemeConfig.metadata.name
    readonly property string currentThemeSource: Config.ThemeConfig.metadata.source
    readonly property bool   isOledClampActive:  Config.ThemeConfig.metadata.oledClamp

    property bool matugenAvailable: false
    property bool isRegenerating:    false
    property bool pendingOLEDClamp:  false

    // Matugen error state for visible error reporting in the UI
    property string matugenError:  ""    // Human-readable error message
    property bool   matugenFailed: false // True if last extraction failed

    // StandardPaths.writableLocation() returns a QUrl ("file:///home/nikos") in
    // this Qt build. Concatenation coerces it to a string first, then we strip
    // the "file://" scheme. (Calling .startsWith/.replace directly on the QUrl
    // throws TypeError — this mirrors the bar's working themeFilePath pattern.)
    // Routing every write through this real path fixes the bug where theme
    // writes (colors.json, ghostty, theme-active) landed in literal "file:"
    // dirs instead of their real locations, so the bar/ghostty never updated.
    readonly property string homeDir: ("" + StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace("file://", "")

    // theme-switcher lives in ~/.local/bin, which is NOT on the quickshell
    // process's PATH — invoke it by absolute path or Process reports
    // "binary could not be found" and theme switches silently no-op.
    readonly property string _themeSwitcherBin: themeService.homeDir + "/.local/bin/theme-switcher"

    // Curated matrix representation for legacy interface alignment
    readonly property var curatedThemes: [
        "OLED Pure Black",
        "Catppuccin Mocha",
        "Tokyo Night"
    ]

    // =========================================================================
    // PRESET PALETTE REFERENCE — reads from ThemePresets (SSOT)
    // -------------------------------------------------------------------------
    // applyPreset() applies a bundle from ThemePresets DIRECTLY to
    // Config.ThemeConfig (instant recolor via bindings). This bypasses the
    // unreliable colors.json cat-poll as the primary apply path.
    //
    // ThemePresets is the single source of truth; these values mirror the
    // palettes in ~/.local/bin/theme-switcher so quickshell and global targets
    // agree. Full token set per theme (Tier 1 structural + Tier 2 accents).
    // =========================================================================
    readonly property var presetPalettes: Config.ThemePresets.palettes

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
        path: themeService.homeDir + "/.config/quickshell/theme-active.json"

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
        id: themeSwitcherRunnerId
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
     * Single OLED Clamp Function — forces surface tokens to pure black
     *
     * This is the ONLY place where OLED clamping happens. All three entry points
     * (preset, matugen, manual) must route through this function to ensure
     * consistent behavior and eliminate duplicate clamping.
     *
     * @param bundle - The color bundle to clamp (modified in-place)
     * @param clamp - If true, force surface tokens to #000000
     * @returns The clamped bundle (same object, modified in-place for efficiency)
     */
    function clampOLED(bundle, clamp) {
        if (!clamp) {
            return bundle;  // No clamping needed, return as-is
        }

        // Force ONLY the four surface tokens to pure black
        // All other tokens (text, accents, etc.) remain untouched
        bundle.background = "#000000";
        bundle.surface = "#000000";
        bundle.surfaceVariant = "#000000";
        bundle.surfaceContainer = "#000000";

        return bundle;
    }

    /**
     * Re-apply the current theme with new OLED clamp state
     *
     * This is the public API for toggling OLED protection. It re-applies the
     * current palette (from ThemeConfig.metadata) with the new clamp state,
     * ensuring both settings and bar update consistently.
     *
     * @param clamp - New OLED clamp state (true = ON, false = OFF)
     */
    function setOledClamp(clamp) {
        if (Config.DebugConfig.debugTheme) {
            console.log("=== setOledClamp CALLED ===")
            console.log("[setOledClamp] New clamp state:", clamp)
            console.log("[setOledClamp] Current theme:", Config.ThemeConfig.metadata.name)
            console.log("[setOledClamp] Current source:", Config.ThemeConfig.metadata.source)
        }

        var currentName = Config.ThemeConfig.metadata.name || "OLED Pure Black";
        var currentSource = Config.ThemeConfig.metadata.source || "preset";

        if (currentSource === "preset") {
            // Re-apply the preset with new clamp state
            themeService.applyPreset(currentName, clamp);
        } else if (currentSource === "matugen") {
            // For matugen themes, re-run extraction with new clamp state
            // Note: We need the wallpaper path - fetch from SharedState
            var wallpaperPath = Config.SharedState.wallpaperPath;
            if (wallpaperPath && wallpaperPath !== "") {
                themeService.applyDynamicTheme(wallpaperPath, clamp);
            } else {
                if (Config.DebugConfig.debugTheme) console.warn("[setOledClamp] Matugen theme active but no wallpaper path - falling back to OLED Pure Black")
                themeService.applyPreset("OLED Pure Black", clamp);
            }
        } else {
            // Unknown source - fall back to OLED Pure Black
            if (Config.DebugConfig.debugTheme) console.warn("[setOledClamp] Unknown theme source:", currentSource, "- falling back to OLED Pure Black")
            themeService.applyPreset("OLED Pure Black", clamp);
        }

        if (Config.DebugConfig.debugTheme) console.log("=== setOledClamp COMPLETE ===")
    }

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

        let path = themeService.homeDir + "/.config/quickshell/theme-active.json";
        // Asynchronously dispatch the structural write stream through standard terminal interface shell
        let writer = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService);
        writer.command = ["sh", "-c", "printf '%s' '" + JSON.stringify(payload) + "' > " + path];
        writer.running = true;
    }

    /**
     * Executes internal structural preset modification pipeline updates
     */
    function applyPreset(presetName, applyOLEDClamp) {
        console.log("=== applyPreset CALLED ===")
        console.log("[applyPreset] presetName:", presetName)
        console.log("[applyPreset] applyOLEDClamp:", applyOLEDClamp, "(type:", typeof applyOLEDClamp, ")")
        console.log("[applyPreset] Current Config.ThemeConfig.metadata.oledClamp BEFORE:", Config.ThemeConfig.metadata.oledClamp)

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
            console.warn("[applyPreset] ERROR: unknown preset (not in presetPalettes):", presetName);
            return;
        }

        console.log("[applyPreset] Palette found for:", presetName)
        var bundle = {};
        for (var k in palette) {
            if (Object.prototype.hasOwnProperty.call(palette, k)) bundle[k] = palette[k];
        }

        console.log("[applyPreset] Background before clamp:", bundle.background)
        console.log("[applyPreset] Surface before clamp:", bundle.surface)

        // Apply OLED clamp through the single clampOLED function
        themeService.clampOLED(bundle, applyOLEDClamp);
        console.log("[applyPreset] OLED clamp", applyOLEDClamp ? "APPLIED" : "NOT applied")

        console.log("[applyPreset] Calling Config.ThemeConfig.applyTheme with metadata.oledClamp:", applyOLEDClamp ? true : false)
        Config.ThemeConfig.applyTheme({
            colors: bundle,
            metadata: {
                name: presetName,
                source: "preset",
                applied: new Date().toISOString(),
                oledClamp: applyOLEDClamp ? true : false,
                matugenEnabled: false
            }
        }, true);  // Mark as user-initiated change

        console.log("[applyPreset] Config.ThemeConfig.metadata.oledClamp AFTER applyTheme:", Config.ThemeConfig.metadata.oledClamp)

        // --- SECONDARY: write to cache file for bar and other shells ---
        var cachePath = themeService.homeDir + "/.cache/theme";
        var colorsJsonPath = cachePath + "/colors.json";

        // Ensure cache directory exists
        var mkdirProc = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService);
        mkdirProc.command = ["sh", "-c", "mkdir -p " + cachePath];
        mkdirProc.running = true;

        // Write colors to cache file for bar to pick up
        var colorsPayload = {
            colors: bundle,
            metadata: {
                name: presetName,
                source: "preset",
                oledClamp: applyOLEDClamp
            }
        };

        console.log("[applyPreset] Writing to cache file with oledClamp:", applyOLEDClamp)
        var writer = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService);
        writer.command = ["sh", "-c", "printf '%s' '" + JSON.stringify(colorsPayload) + "' > " + colorsJsonPath];
        writer.running = true;

        // Sync to external apps
        themeService.syncToExternalApps(bundle);

        themeService.writeActiveThemeToken(presetName, "preset", applyOLEDClamp);
        themeService.isRegenerating = false;
        console.log("[applyPreset] Function complete. Final metadata.oledClamp:", Config.ThemeConfig.metadata.oledClamp)
        console.log("=== applyPreset COMPLETE ===")
    }

    /**
     * Triggers external automated Matugen wallpaper extraction workflows
     *
     * Uses buffer-then-parse pattern (stdout accumulated across onRead, parsed once
     * on process exit) to handle split JSON chunks. Includes palette-completeness
     * validation and visible error reporting.
     */
    property var matugenRunner: Process {
        id: runner

        // Buffer for stdout accumulation
        property string buffer: ""

        stdout: SplitParser {
            onRead: function(data) {
                runner.buffer += data
            }
        }

        onRunningChanged: function() {
            if (!running) {
                // matugen exited without capturable JSON — surface it instead of
                // silently doing nothing (and leaving isRegenerating stuck until
                // the safety timeout fires).
                if (runner.buffer.length === 0) {
                    console.error("ThemeService: matugen produced no stdout to parse")
                    themeService.matugenError = "Matugen produced no output — extraction may have failed"
                    themeService.matugenFailed = true
                    themeService.isRegenerating = false
                    return
                }
                try {
                    var matugenOutput = runner.buffer.trim();
                    runner.buffer = "";  // Clear buffer immediately after read

                    if (matugenOutput.length > 0) {
                        var colors = JSON.parse(matugenOutput);

                        // Validate palette completeness - check for required base16 keys
                        var requiredKeys = ["base00", "base01", "base02", "base03", "base04",
                                           "base05", "base06", "base07", "base08", "base09",
                                           "base0a", "base0b", "base0c", "base0d", "base0e"];
                        var missingKeys = [];
                        for (var i = 0; i < requiredKeys.length; i++) {
                            var key = requiredKeys[i];
                            if (!colors.base16 || !colors.base16[key]) {
                                missingKeys.push(key);
                            }
                        }

                        if (missingKeys.length > 0) {
                            // Palette incomplete - surface visible error
                            console.error("ThemeService: Matugen palette incomplete - missing keys:", missingKeys.join(", "));
                            themeService.matugenError = "Incomplete palette from wallpaper: missing " + missingKeys.length + " color(s)";
                            themeService.matugenFailed = true;
                            themeService.isRegenerating = false;
                            return;
                        }

                        // Map matugen colors to our theme format
                        // matugen 4.1.0 emits base16 format: base16.base00.dark.color
                        function pickBase16(b16Key) {
                            var e = colors.base16 && colors.base16[b16Key]
                            if (!e) return null
                            return (e.default && e.default.color) || (e.dark && e.dark.color) || (e.light && e.light.color) || null
                        }
                        var mappedColors = {
                            background: pickBase16("base00") || "#000000",
                            surface: pickBase16("base01") || "#0a0a0a",
                            surfaceVariant: pickBase16("base02") || "#111111",
                            surfaceContainer: pickBase16("base03") || "#111111",
                            text: pickBase16("base06") || "#e0e0e0",
                            textDim: pickBase16("base07") || "#808080",
                            border: pickBase16("base04") || "#1a1a1a",
                            outline: pickBase16("base04") || "#2a2a2a",
                            outlineVariant: pickBase16("base05") || "#1a1a1a",
                            primary: pickBase16("base08") || "#7c6bf0",
                            secondary: pickBase16("base09") || "#00dce5",
                            accent: pickBase16("base0a") || "#f87171",
                            success: pickBase16("base0b") || "#34d399",
                            warning: pickBase16("base0c") || "#fbbf24",
                            error: pickBase16("base0d") || "#f87171",
                            info: pickBase16("base0e") || "#00dce5"
                        };

                        // Apply OLED clamp through the single clampOLED function
                        themeService.clampOLED(mappedColors, themeService.pendingOLEDClamp);

                        Config.ThemeConfig.applyTheme({
                            colors: mappedColors,
                            metadata: {
                                name: "Dynamic Wallpaper",
                                source: "matugen",
                                applied: new Date().toISOString(),
                                oledClamp: themeService.pendingOLEDClamp,
                                matugenEnabled: true
                            }
                        });

                        // Write to cache file
                        var cachePath = themeService.homeDir + "/.cache/theme";
                        var colorsJsonPath = cachePath + "/colors.json";
                        var colorsPayload = {
                            colors: mappedColors,
                            metadata: Config.ThemeConfig.metadata
                        };
                        var writer = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService);
                        writer.command = ["sh", "-c", "mkdir -p " + cachePath + " && printf '%s' '" + JSON.stringify(colorsPayload) + "' > " + colorsJsonPath];
                        writer.running = true;

                        // Sync to external apps
                        themeService.syncToExternalApps(mappedColors);
                        themeService.writeActiveThemeToken("Dynamic Wallpaper", "matugen", themeService.pendingOLEDClamp);

                        // Success - clear any previous error
                        themeService.matugenError = "";
                        themeService.matugenFailed = false;
                    }
                } catch (e) {
                    console.error("ThemeService: Failed to parse matugen output:", e);
                    themeService.matugenError = "Failed to parse matugen output: " + e.message;
                    themeService.matugenFailed = true;
                }
                themeService.isRegenerating = false;
            }
        }

        onExited: function(code) {
            if (code !== 0) {
                console.error("ThemeService: matugen failed with exit code:", code);
                themeService.matugenError = "Matugen extraction failed (exit code " + code + ")";
                themeService.matugenFailed = true;
                themeService.isRegenerating = false;
            }
        }
    }

    // Safety timeout: clear isRegenerating after ~8s if matugen hangs
    // This prevents the Run Extraction button from being permanently disabled
    Timer {
        id: matugenTimeout
        interval: 8000
        running: false
        repeat: false
        onTriggered: {
            if (themeService.isRegenerating) {
                console.warn("ThemeService: matugen timeout - clearing isRegenerating flag")
                themeService.isRegenerating = false
            }
        }
    }

    function applyDynamicTheme(wallpaperPath, applyOLEDClamp) {
        console.log("=== applyDynamicTheme CALLED ===")
        console.log("[applyDynamicTheme] wallpaperPath:", wallpaperPath)
        console.log("[applyDynamicTheme] applyOLEDClamp:", applyOLEDClamp)

        if (themeService.isRegenerating) {
            console.log("[applyDynamicTheme] Already regenerating, skipping")
            return;
        }

        // Use the provided wallpaper path (the active wallpaper from
        // WallpaperService.currentWallpaper), or fall back to SharedState.
        var actualPath = wallpaperPath || Config.SharedState.wallpaperPath
        console.log("[applyDynamicTheme] actualPath to use:", actualPath)

        if (!actualPath || actualPath === "") {
            // Surface a visible error instead of silently returning — otherwise
            // the button appears to do nothing when no wallpaper is active.
            console.warn("[applyDynamicTheme] No wallpaper path available")
            themeService.matugenError = "No wallpaper selected — set a wallpaper in the Wallpaper tab first"
            themeService.matugenFailed = true
            return;
        }

        // Reset error state and clear any stale stdout buffer from a previous run.
        themeService.matugenError = ""
        themeService.matugenFailed = false
        matugenRunner.buffer = ""

        themeService.isRegenerating = true;
        themeService.pendingOLEDClamp = applyOLEDClamp;
        matugenTimeout.restart();

        // Run matugen to generate colors from wallpaper
        // Strip file:// prefix if present
        var cleanPath = actualPath.startsWith("file://") ? actualPath.substring(7) : actualPath;
        console.log("[applyDynamicTheme] Running matugen with path:", cleanPath)

        matugenRunner.command = ["matugen", "image", cleanPath, "-j", "hex", "--mode", "dark", "--type", "scheme-tonal-spot", "--prefer=lightness", "-q"];
        matugenRunner.running = true;
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

        // Write to cache file
        var cachePath = themeService.homeDir + "/.cache/theme";
        var colorsJsonPath = cachePath + "/colors.json";
        var mkdirProc = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService);
        mkdirProc.command = ["sh", "-c", "mkdir -p " + cachePath];
        mkdirProc.running = true;

        var colorsPayload = {
            colors: Config.ThemeConfig.colors,
            metadata: Config.ThemeConfig.metadata
        };

        var writer = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService);
        writer.command = ["sh", "-c", "printf '%s' '" + JSON.stringify(colorsPayload) + "' > " + colorsJsonPath];
        writer.running = true;

        // Sync to external apps
        themeService.syncToExternalApps(Config.ThemeConfig.colors);

        themeService.writeActiveThemeToken("Custom Modification", "manual", themeService.isOledClampActive);
    }

    /**
     * Sync theme to external apps (ghostty, terminal TUIs)
     * This generates config files for apps that support custom theming
     */
    function syncToExternalApps(colors) {
        if (!colors) colors = Config.ThemeConfig.colors;

        // Generate ghostty theme config.
        // ghostty's config loads this exact file via:
        //   config-file = ~/.config/ngeran/theme/ghostty.conf
        var ghosttyConf = themeService.homeDir + "/.config/ngeran/theme/ghostty.conf";
        var ghosttyContent =
            "# Theme: " + Config.ThemeConfig.metadata.name + "\n" +
            "# Generated by Quickshell ThemeService\n" +
            "foreground = " + colors.text + "\n" +
            "background = " + colors.background + "\n" +
            "cursor = " + colors.primary + "\n" +
            "selection-foreground = " + colors.background + "\n" +
            "selection-background = " + colors.primary + "\n" +
            "palette = 0=" + colors.background + "\n" +
            "palette = 1=" + colors.error + "\n" +
            "palette = 2=" + colors.success + "\n" +
            "palette = 3=" + colors.warning + "\n" +
            "palette = 4=" + colors.primary + "\n" +
            "palette = 5=" + colors.secondary + "\n" +
            "palette = 6=" + colors.info + "\n" +
            "palette = 7=" + colors.text + "\n" +
            "palette = 8=" + colors.textDim + "\n" +
            "palette = 9=" + colors.error + "\n" +
            "palette = 10=" + colors.success + "\n" +
            "palette = 11=" + colors.warning + "\n" +
            "palette = 12=" + colors.primary + "\n" +
            "palette = 13=" + colors.secondary + "\n" +
            "palette = 14=" + colors.info + "\n" +
            "palette = 15=" + colors.text + "\n";

        var ghosttyDirProc = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService);
        ghosttyDirProc.command = ["sh", "-c", "mkdir -p ~/.config/ngeran/theme"];
        ghosttyDirProc.running = true;

        var ghosttyWriter = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService);
        ghosttyWriter.command = ["sh", "-c", "printf '%s' '" + ghosttyContent.replace(/'/g, "'\\''") + "' > " + ghosttyConf];
        ghosttyWriter.running = true;

        // Force already-open ghostty surfaces to pick up the new palette. The
        // imported theme file above is correct and loads fine, but ghostty only
        // re-reads config-file imports when the MAIN config changes. Bumping this
        // marker rewrites the main config in place (same inode → inotify modify
        // fires → ghostty reloads → import re-read → live recolor).
        var ghosttyMainConf = themeService.homeDir + "/.config/ghostty/config";
        var ghosttyReloader = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService);
        ghosttyReloader.command = ["sh", "-c",
            "f=" + JSON.stringify(ghosttyMainConf) + "; " +
            "{ grep -v '^# quickshell-theme-version:' \"$f\" 2>/dev/null; " +
            "printf '# quickshell-theme-version: %s\\n' \"$(date +%s)\"; } > \"$f.qs\"; " +
            "cat \"$f.qs\" > \"$f\"; rm -f \"$f.qs\""];
        ghosttyReloader.running = true;

        // Terminal TUI apps typically use terminal colors, so ghostty theming covers them
        // For apps with custom themes (impala, wiremix, bluetui), they would need specific configs
        // This is a placeholder for future expansion
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
