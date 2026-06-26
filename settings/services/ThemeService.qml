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
    // CUSTOM SCHEMES — user-saved palettes (max 5), persisted to
    // ~/.config/quickshell/custom-themes.json so they survive reboot.
    // =========================================================================
    property var customThemes: []
    readonly property string customThemesPath: themeService.homeDir + "/.config/quickshell/custom-themes.json"

    Component.onCompleted: themeService.loadCustomThemes()

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
    // =========================================================================
    // NORMALIZATION + CONTRAST HELPERS (shared by preset + matugen paths)
    // -------------------------------------------------------------------------
    // normalizeBundle() emits the canonical 16-token shape from any raw color
    // object so presets and matugen output are structurally identical; missing
    // tokens fall back to defaultBundle. luminance() powers the OLED-clamp text
    // safeguard in clampOLED().
    // =========================================================================

    readonly property var defaultBundle: ({
        background: "#000000", surface: "#0a0a0a", surfaceVariant: "#111111",
        surfaceContainer: "#111111", text: "#e0e0e0", textDim: "#808080",
        border: "#1a1a1a", outline: "#2a2a2a", outlineVariant: "#1a1a1a",
        primary: "#7c6bf0", secondary: "#00dce5", accent: "#f87171",
        success: "#34d399", warning: "#fbbf24", error: "#f87171", info: "#00dce5"
    })

    // Relative luminance (0..1, sRGB) of a "#rrggbb" string; invalid → 0.
    function luminance(hex) {
        var h = (hex || "#000000").replace("#", "")
        if (h.length !== 6) return 0
        var ch = function (s) {
            var v = parseInt(s, 16) / 255
            return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * ch(h.substring(0, 2)) + 0.7152 * ch(h.substring(2, 4)) + 0.0722 * ch(h.substring(4, 6))
    }

    // Canonical 16-token bundle from a raw/partial color object.
    function normalizeBundle(raw) {
        var d = themeService.defaultBundle
        var has = function (k) { return raw && typeof raw[k] === "string" && raw[k].charAt(0) === "#" }
        var pick = function (k, fb) { return has(k) ? raw[k] : fb }
        return {
            background:       pick("background", d.background),
            surface:          pick("surface", d.surface),
            surfaceVariant:   pick("surfaceVariant", d.surfaceVariant),
            surfaceContainer: pick("surfaceContainer", has("surfaceVariant") ? raw.surfaceVariant : d.surfaceContainer),
            text:             pick("text", d.text),
            textDim:          pick("textDim", d.textDim),
            border:           pick("border", d.border),
            outline:          pick("outline", d.outline),
            outlineVariant:   pick("outlineVariant", d.outlineVariant),
            primary:          pick("primary", d.primary),
            secondary:        pick("secondary", d.secondary),
            accent:           pick("accent", d.accent),
            success:          pick("success", d.success),
            warning:          pick("warning", d.warning),
            error:            pick("error", d.error),
            info:             pick("info", d.info)
        }
    }

    function clampOLED(bundle, clamp) {
        if (!clamp) {
            return bundle;  // No clamping needed, return as-is
        }

        // Force ONLY the four surface tokens to pure black
        bundle.background = "#000000";
        bundle.surface = "#000000";
        bundle.surfaceVariant = "#000000";
        bundle.surfaceContainer = "#000000";

        // Pure-black bg: guarantee text legibility. If the source palette's text
        // is too dim to read on #000, fall back to the default light tokens.
        if (themeService.luminance(bundle.text) < 0.18)
            bundle.text = themeService.defaultBundle.text;
        if (themeService.luminance(bundle.textDim) < 0.12)
            bundle.textDim = themeService.defaultBundle.textDim;

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
        if (Config.DebugConfig.debugTheme) console.log("=== setOledClamp CALLED ===")
        if (Config.DebugConfig.debugTheme) console.log("[setOledClamp] New clamp state:", clamp)
        if (Config.DebugConfig.debugTheme) console.log("[setOledClamp] Current theme:", Config.ThemeConfig.metadata.name)
        if (Config.DebugConfig.debugTheme) console.log("[setOledClamp] Current source:", Config.ThemeConfig.metadata.source)

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
        if (Config.DebugConfig.debugTheme) console.log("=== applyPreset CALLED ===")
        if (Config.DebugConfig.debugTheme) console.log("[applyPreset] presetName:", presetName)
        if (Config.DebugConfig.debugTheme) console.log("[applyPreset] applyOLEDClamp:", applyOLEDClamp, "(type:", typeof applyOLEDClamp, ")")
        if (Config.DebugConfig.debugTheme) console.log("[applyPreset] Current Config.ThemeConfig.metadata.oledClamp BEFORE:", Config.ThemeConfig.metadata.oledClamp)

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

        if (Config.DebugConfig.debugTheme) console.log("[applyPreset] Palette found for:", presetName)
        var bundle = themeService.normalizeBundle(palette);

        if (Config.DebugConfig.debugTheme) console.log("[applyPreset] Background before clamp:", bundle.background)
        if (Config.DebugConfig.debugTheme) console.log("[applyPreset] Surface before clamp:", bundle.surface)

        // Apply OLED clamp through the single clampOLED function
        themeService.clampOLED(bundle, applyOLEDClamp);
        if (Config.DebugConfig.debugTheme) console.log("[applyPreset] OLED clamp", applyOLEDClamp ? "APPLIED" : "NOT applied")

        if (Config.DebugConfig.debugTheme) console.log("[applyPreset] Calling Config.ThemeConfig.applyTheme with metadata.oledClamp:", applyOLEDClamp ? true : false)
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

        if (Config.DebugConfig.debugTheme) console.log("[applyPreset] Config.ThemeConfig.metadata.oledClamp AFTER applyTheme:", Config.ThemeConfig.metadata.oledClamp)

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

        if (Config.DebugConfig.debugTheme) console.log("[applyPreset] Writing to cache file with oledClamp:", applyOLEDClamp)
        var writer = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService);
        writer.command = ["sh", "-c", "printf '%s' '" + JSON.stringify(colorsPayload) + "' > " + colorsJsonPath];
        writer.running = true;

        // Sync to external apps
        themeService.syncToExternalApps(bundle);

        themeService.writeActiveThemeToken(presetName, "preset", applyOLEDClamp);
        themeService.isRegenerating = false;
        if (Config.DebugConfig.debugTheme) console.log("[applyPreset] Function complete. Final metadata.oledClamp:", Config.ThemeConfig.metadata.oledClamp)
        if (Config.DebugConfig.debugTheme) console.log("=== applyPreset COMPLETE ===")
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

                        // Validate the Material palette — the vivid source we map from.
                        // base16 slots are tonal and render near-black on dark wallpapers,
                        // so we map from colors.* (Material You) for vivid accents.
                        var m = colors.colors || {}
                        var requiredM = ["primary", "secondary", "tertiary", "error", "surface", "on_surface"]
                        var missingM = []
                        for (var i = 0; i < requiredM.length; i++) {
                            if (!m[requiredM[i]]) missingM.push(requiredM[i])
                        }
                        if (missingM.length > 0) {
                            console.error("ThemeService: Matugen Material palette incomplete - missing:", missingM.join(", "))
                            themeService.matugenError = "Incomplete palette from wallpaper: missing " + missingM.length + " color(s)"
                            themeService.matugenFailed = true
                            themeService.isRegenerating = false
                            return
                        }

                        // Map matugen Material colors → canonical tokens. Brand accents
                        // come from colors.primary/secondary/tertiary; secondary (the
                        // unified accent) is driven by colors.primary — the vivid
                        // saturated swatch. success/warning/info stay as fixed semantic
                        // colors (Material has no equivalents). normalizeBundle() fills
                        // gaps and guarantees the same 16-token shape as presets.
                        function pickM(key) {
                            var e = m[key]
                            if (!e) return null
                            return (e.default && e.default.color) || (e.dark && e.dark.color) || (e.light && e.light.color) || null
                        }
                        var bundle = themeService.normalizeBundle({
                            background: pickM("background"),
                            surface: pickM("surface"),
                            surfaceVariant: pickM("surface_variant"),
                            surfaceContainer: pickM("surface_container"),
                            text: pickM("on_surface"),
                            textDim: pickM("on_surface_variant"),
                            border: pickM("outline_variant"),
                            outline: pickM("outline"),
                            outlineVariant: pickM("outline_variant"),
                            primary: pickM("tertiary"),
                            secondary: pickM("primary"),
                            accent: pickM("secondary"),
                            success: "#34d399",
                            warning: "#fbbf24",
                            error: pickM("error"),
                            info: "#00dce5"
                        })

                        // Apply OLED clamp through the single clampOLED function
                        themeService.clampOLED(bundle, themeService.pendingOLEDClamp);

                        Config.ThemeConfig.applyTheme({
                            colors: bundle,
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
                            colors: bundle,
                            metadata: Config.ThemeConfig.metadata
                        };
                        var writer = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService);
                        writer.command = ["sh", "-c", "mkdir -p " + cachePath + " && printf '%s' '" + JSON.stringify(colorsPayload) + "' > " + colorsJsonPath];
                        writer.running = true;

                        // Sync to external apps
                        themeService.syncToExternalApps(bundle);
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
        if (Config.DebugConfig.debugTheme) console.log("=== applyDynamicTheme CALLED ===")
        if (Config.DebugConfig.debugTheme) console.log("[applyDynamicTheme] wallpaperPath:", wallpaperPath)
        if (Config.DebugConfig.debugTheme) console.log("[applyDynamicTheme] applyOLEDClamp:", applyOLEDClamp)

        if (themeService.isRegenerating) {
            if (Config.DebugConfig.debugTheme) console.log("[applyDynamicTheme] Already regenerating, skipping")
            return;
        }

        // Use the provided wallpaper path (the active wallpaper from
        // WallpaperService.currentWallpaper), or fall back to SharedState.
        var actualPath = wallpaperPath || Config.SharedState.wallpaperPath
        if (Config.DebugConfig.debugTheme) console.log("[applyDynamicTheme] actualPath to use:", actualPath)

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
        if (Config.DebugConfig.debugTheme) console.log("[applyDynamicTheme] Running matugen with path:", cleanPath)

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

    // =========================================================================
    // CUSTOM SCHEME PERSISTENCE + API
    // =========================================================================

    // Reads saved custom schemes from disk (called on startup + after writes).
    property var customThemeLoader: Process {
        id: customLoader
        property string buffer: ""
        command: ["sh", "-c", "cat " + themeService.customThemesPath + " 2>/dev/null"]
        stdout: SplitParser { onRead: function(data) { customLoader.buffer += data } }
        onRunningChanged: {
            if (!running) {
                try {
                    var raw = customLoader.buffer.trim()
                    if (raw.length > 0) {
                        var arr = JSON.parse(raw)
                        themeService.customThemes = Array.isArray(arr) ? arr : []
                    }
                } catch (e) { /* no/invalid file yet */ }
                customLoader.buffer = ""
            }
        }
    }

    function loadCustomThemes() { customLoader.running = true }

    // Snapshot the current palette as a named scheme (max 5; oldest dropped).
    function saveCustomTheme(name) {
        var n = (name || "").trim()
        if (n.length === 0) return
        var entry = { name: n, colors: {} }
        var c = Config.ThemeConfig.colors
        for (var k in c) {
            if (Object.prototype.hasOwnProperty.call(c, k)) entry.colors[k] = c[k]
        }
        var arr = themeService.customThemes.filter(function(e) { return e.name !== n })
        arr.unshift(entry)
        if (arr.length > 5) arr = arr.slice(0, 5)
        themeService.customThemes = arr
        themeService._writeCustomThemes()
    }

    function deleteCustomTheme(name) {
        themeService.customThemes = themeService.customThemes.filter(function(e) { return e.name !== name })
        themeService._writeCustomThemes()
    }

    // Apply a saved scheme through the standard pipeline (bar/ghostty/nvim update).
    function applyCustomTheme(name) {
        var found = null
        for (var i = 0; i < themeService.customThemes.length; i++) {
            if (themeService.customThemes[i].name === name) { found = themeService.customThemes[i]; break }
        }
        if (!found || !found.colors) return

        var bundle = themeService.normalizeBundle(found.colors)
        themeService.clampOLED(bundle, themeService.isOledClampActive)
        Config.ThemeConfig.applyTheme({
            colors: bundle,
            metadata: {
                name: found.name,
                source: "custom",
                applied: new Date().toISOString(),
                oledClamp: themeService.isOledClampActive,
                matugenEnabled: false
            }
        }, true)

        var cachePath = themeService.homeDir + "/.cache/theme"
        var colorsJsonPath = cachePath + "/colors.json"
        var colorsPayload = { colors: bundle, metadata: Config.ThemeConfig.metadata }
        var writer = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService)
        writer.command = ["sh", "-c", "mkdir -p " + cachePath + " && printf '%s' '" + JSON.stringify(colorsPayload) + "' > " + colorsJsonPath]
        writer.running = true
        themeService.syncToExternalApps(bundle)
        themeService.writeActiveThemeToken(found.name, "custom", themeService.isOledClampActive)
    }

    function _writeCustomThemes() {
        var payload = JSON.stringify(themeService.customThemes)
        var writer = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService)
        writer.command = ["sh", "-c", "printf '%s' '" + payload.replace(/'/g, "'\\''") + "' > " + themeService.customThemesPath]
        writer.running = true
    }

    /**
     * Sync theme to external apps (ghostty, terminal TUIs)
     * This generates config files for apps that support custom theming
     */
    function syncToExternalApps(colors) {
        if (!colors) colors = Config.ThemeConfig.colors;

        // ghostty: write a managed palette block directly into the MAIN config.
        // ghostty reliably watches + reloads its main config on content change
        // (not config-file imports), and a trailing managed block overrides
        // anything earlier — so open terminals pick up the new colors live.
        // python3 does the read→strip→append (avoids shell quoting issues).
        var ghosttyMain = themeService.homeDir + "/.config/ghostty/config";
        var ghosttyLines = [
            "background = " + colors.background,
            "foreground = " + colors.text,
            "cursor-color = " + colors.primary,
            "selection-background = " + colors.primary,
            "selection-foreground = " + colors.background,
            "palette = 0=" + colors.background,
            "palette = 1=" + colors.error,
            "palette = 2=" + colors.success,
            "palette = 3=" + colors.warning,
            "palette = 4=" + colors.primary,
            "palette = 5=" + colors.secondary,
            "palette = 6=" + colors.info,
            "palette = 7=" + colors.text,
            "palette = 8=" + colors.textDim,
            "palette = 9=" + colors.error,
            "palette = 10=" + colors.success,
            "palette = 11=" + colors.warning,
            "palette = 12=" + colors.primary,
            "palette = 13=" + colors.secondary,
            "palette = 14=" + colors.info,
            "palette = 15=" + colors.text
        ].join("\n");
        var ghosttyPy = [
            "import os",
            "f = " + JSON.stringify(ghosttyMain),
            "lines = " + JSON.stringify(ghosttyLines),
            "orig = open(f).read() if os.path.exists(f) else ''",
            "s = orig[:orig.find('# >>> quickshell-theme >>>')] if '# >>> quickshell-theme >>>' in orig else orig",
            "s = '\\n'.join(l for l in s.split('\\n') if not l.startswith('# quickshell-theme-version:'))",
            "s = s.rstrip()",
            "open(f, 'w').write(s + '\\n\\n# >>> quickshell-theme >>>\\n' + lines + '\\n# <<< quickshell-theme <<<\\n')"
        ].join("\n");
        var ghosttyWriter = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService);
        ghosttyWriter.command = ["python3", "-c", ghosttyPy];
        ghosttyWriter.running = true;
    }
}
