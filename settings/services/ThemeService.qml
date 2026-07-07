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

    property bool isRegenerating:    false
    property bool pendingOLEDClamp:  false

    // Regeneration error state for visible error reporting in the UI
    property string regenError:  ""    // Human-readable error message
    property bool   regenFailed: false // True if last operation failed

    // StandardPaths.writableLocation() returns a QUrl ("file:///home/nikos") in
    // this Qt build. Concatenation coerces it to a string first, then we strip
    // the "file://" scheme. (Calling .startsWith/.replace directly on the QUrl
    // throws TypeError — this mirrors the bar's working themeFilePath pattern.)
    // Routing every write through this real path fixes the bug where theme
    // writes (colors.json, ghostty, theme-active) landed in literal "file:"
    // dirs instead of their real locations, so the bar/ghostty never updated.
    readonly property string homeDir: ("" + StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace("file://", "")

    // =========================================================================
    // PROCESS CREATION WITH ERROR HANDLING
    // =========================================================================

    function createProcess(cmd, label) {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService);
        proc.command = cmd;

        // Add error logging
        proc.onExited.connect(function(code) {
            if (code !== 0) {
                var errorMsg = "Process failed with exit code " + code + ": " + (label || "unknown");
                console.error("[ThemeService] " + errorMsg);
                CommandService.pushLog("[ThemeService] " + errorMsg, "error");
            }
        });

        return proc;
    }

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

    Component.onCompleted: {
        themeService.loadCustomThemes();
        // Load Stylix seed on startup (will be applied if colors.json is absent or stale)
        themeService.loadStylixSeed();
    }

    // =========================================================================
    // INTERFACE MANIPULATION METHODS
    // =========================================================================

    /**
     * Single OLED Clamp Function — forces surface tokens to pure black
     *
     * This is the ONLY place where OLED clamping happens. All entry points
     * (preset, manual, stylix seed) must route through this function to ensure
     * consistent behavior and eliminate duplicate clamping.
     *
     * @param bundle - The color bundle to clamp (modified in-place)
     * @param clamp - If true, force surface tokens to #000000
     * @returns The clamped bundle (same object, modified in-place for efficiency)
     */
    // =========================================================================
    // NORMALIZATION + CONTRAST HELPERS (shared by preset + stylix paths)
    // -------------------------------------------------------------------------
    // normalizeBundle() emits the canonical 16-token shape from any raw color
    // object so presets and stylix output are structurally identical; missing
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
     * Writes the theme bundle to ~/.cache/theme/colors.json (bar sync channel)
     *
     * Consolidated helper for all four write sites (preset, stylix seed, manual,
     * custom). Performs mkdir + write atomically via sh -c to avoid races.
     */
    function _writeColorsJson(bundle, metadata) {
        var cachePath = themeService.homeDir + "/.cache/theme";
        var colorsJsonPath = cachePath + "/colors.json";
        var colorsPayload = { colors: bundle, metadata: metadata };
        var writer = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService);
        writer.command = ["sh", "-c", "mkdir -p " + cachePath + " && printf '%s' '" + JSON.stringify(colorsPayload) + "' > " + colorsJsonPath];
        writer.onExited.connect(function(code) {
            if (code !== 0) {
                var errorMsg = "Failed to write colors.json (exit " + code + "). Theme may not sync to bar.";
                console.error("[ThemeService] " + errorMsg);
                CommandService.pushLog("[ThemeService] " + errorMsg, "error");
            }
        });
        writer.running = true;
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
        } else if (currentSource === "stylix") {
            // Stylix themes: re-apply the seed with new clamp state
            themeService.loadStylixSeed();
            var bundle = themeService.normalizeBundle(Config.ThemeConfig.colors);
            themeService.clampOLED(bundle, clamp);
            Config.ThemeConfig.applyTheme({
                colors: bundle,
                metadata: {
                    name: Config.ThemeConfig.metadata.name,
                    source: "stylix",
                    applied: new Date().toISOString(),
                    oledClamp: clamp
                }
            }, true);
            themeService._writeColorsJson(bundle, Config.ThemeConfig.metadata);
            themeService.syncToExternalApps(bundle);
        } else {
            // Unknown source - fall back to OLED Pure Black
            if (Config.DebugConfig.debugTheme) console.warn("[setOledClamp] Unknown theme source:", currentSource, "- falling back to OLED Pure Black")
            themeService.applyPreset("OLED Pure Black", clamp);
        }

        if (Config.DebugConfig.debugTheme) console.log("=== setOledClamp COMPLETE ===")
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
                oledClamp: applyOLEDClamp ? true : false
            }
        }, true);  // Mark as user-initiated change

        if (Config.DebugConfig.debugTheme) console.log("[applyPreset] Config.ThemeConfig.metadata.oledClamp AFTER applyTheme:", Config.ThemeConfig.metadata.oledClamp)

        // --- SECONDARY: write to cache file for bar and other shells ---
        themeService._writeColorsJson(bundle, {
            name: presetName,
            source: "preset",
            oledClamp: applyOLEDClamp
        });

        // Sync to external apps
        themeService.syncToExternalApps(bundle);

        themeService.isRegenerating = false;
        if (Config.DebugConfig.debugTheme) console.log("[applyPreset] Function complete. Final metadata.oledClamp:", Config.ThemeConfig.metadata.oledClamp)
        if (Config.DebugConfig.debugTheme) console.log("=== applyPreset COMPLETE ===")
    }

    /**
     * Triggers rebuild to apply Stylix palette from a new wallpaper
     *
     * Copies the chosen wallpaper into the flake tree and rebuilds; Stylix
     * regenerates the seed from the new image. After rebuild succeeds,
     * loadStylixSeed() applies the new palette to colors.json.
     */
    property var rebuildRunner: Process {
        id: rebuilder
        property string buffer: ""

        stdout: SplitParser {
            onRead: function(data) { rebuilder.buffer += data }
        }

        onRunningChanged: function() {
            if (!running) {
                // Reset state regardless of buffer length — a no-op rebuild may
                // emit little/no stdout, and we must not leave isRegenerating
                // stuck true (which would disable the button for 60s until
                // rebuildTimeout fires).
                console.log("[ThemeService] Rebuild output:", rebuilder.buffer.trim());
                themeService.isRegenerating = false;
                themeService.regenFailed = (rebuilder.buffer.search(/error|fail/i) !== -1);
                themeService.regenError = themeService.regenFailed ? "Rebuild failed - check logs" : "";
                // On successful rebuild, reload the Stylix seed
                if (!themeService.regenFailed) {
                    themeService.loadStylixSeed();
                }
                rebuilder.buffer = "";
            }
        }

        onExited: function(code) {
            if (code !== 0) {
                console.error("ThemeService: rebuild failed with exit code:", code);
                themeService.regenError = "Rebuild failed (exit code " + code + ")";
                themeService.regenFailed = true;
                themeService.isRegenerating = false;
            }
        }
    }

    // Safety timeout: clear isRegenerating after 60s if rebuild hangs
    Timer {
        id: rebuildTimeout
        interval: 60000
        running: false
        repeat: false
        onTriggered: {
            if (themeService.isRegenerating) {
                console.warn("ThemeService: rebuild timeout - clearing isRegenerating flag")
                themeService.regenError = "Rebuild timed out";
                themeService.regenFailed = true;
                themeService.isRegenerating = false;
            }
        }
    }

    function applyDynamicTheme(wallpaperPath, applyOLEDClamp_unused) {
        if (Config.DebugConfig.debugTheme) console.log("=== applyDynamicTheme CALLED ===")
        if (Config.DebugConfig.debugTheme) console.log("[applyDynamicTheme] wallpaperPath:", wallpaperPath)
        if (Config.DebugConfig.debugTheme) console.log("[applyDynamicTheme] applyOLEDClamp:", applyOLEDClamp_unused)

        if (themeService.isRegenerating) {
            if (Config.DebugConfig.debugTheme) console.log("[applyDynamicTheme] Already regenerating, skipping")
            return;
        }

        // Use the provided wallpaper path (the active wallpaper from
        // WallpaperService.currentWallpaper), or fall back to SharedState.
        var actualPath = wallpaperPath || Config.SharedState.wallpaperPath
        if (Config.DebugConfig.debugTheme) console.log("[applyDynamicTheme] actualPath to use:", actualPath)

        if (!actualPath || actualPath === "") {
            console.warn("[applyDynamicTheme] No wallpaper path available")
            themeService.regenError = "No wallpaper selected — set a wallpaper in the Wallpaper tab first"
            themeService.regenFailed = true
            return;
        }

        // Reset error state and clear any stale stdout buffer from a previous run.
        themeService.regenError = ""
        themeService.regenFailed = false
        rebuildRunner.buffer = ""

        themeService.isRegenerating = true;
        rebuildTimeout.restart();

        // Strip file:// prefix if present
        var cleanPath = actualPath.startsWith("file://") ? actualPath.substring(7) : actualPath;
        if (Config.DebugConfig.debugTheme) console.log("[applyDynamicTheme] Triggering rebuild with wallpaper:", cleanPath)

        rebuildRunner.command = ["pkexec", "/run/current-system/sw/bin/qs-apply-wallpaper", cleanPath];
        rebuildRunner.running = true;
    }

    /**
     * Loads the Stylix seed palette and applies it as the active theme
     *
     * Reads ~/.config/quickshell/stylix-palette.json (written by Stylix's
     * home-manager module) and pushes it to ThemeConfig + colors.json.
     * Called on Component.onCompleted (only if colors.json is absent or
     * source === "stylix") and after successful rebuilds. The clobber guard
     * prevents overwriting a user's live preset choice on every launch.
     */
    // Helper process for checking colors.json before loading Stylix seed
    property var stylixChecker: Process {
        property string buffer: ""
        command: []
        stdout: SplitParser {
            onRead: function(data) {
                stylixChecker.buffer += data
            }
        }
        onExited: function(code) {
            var shouldLoadSeed = true;
            if (stylixChecker.buffer.trim() !== "NONE") {
                try {
                    var existing = JSON.parse(stylixChecker.buffer.trim());
                    if (existing.metadata && existing.metadata.source && existing.metadata.source !== "stylix") {
                        shouldLoadSeed = false;
                        console.log("[ThemeService] Skipping Stylix seed - existing theme:", existing.metadata.name);
                    }
                } catch (e) {
                    // File exists but invalid, load seed
                }
            }
            if (shouldLoadSeed) {
                stylixSeedLoader.running = true;
            }
            stylixChecker.buffer = "";
        }
    }

    property var stylixSeedLoader: Process {
        property string buffer: ""
        command: ["sh", "-c", "cat ~/.config/quickshell/stylix-palette.json 2>/dev/null"]
        stdout: SplitParser {
            onRead: function(data) { stylixSeedLoader.buffer += data }
        }
        onRunningChanged: {
            if (!running && stylixSeedLoader.buffer.length > 0) {
                try {
                    var seed = JSON.parse(stylixSeedLoader.buffer.trim());
                    if (seed && seed.colors && seed.metadata) {
                        var bundle = themeService.normalizeBundle(seed.colors);
                        Config.ThemeConfig.applyTheme({
                            colors: bundle,
                            metadata: seed.metadata
                        });
                        themeService._writeColorsJson(bundle, seed.metadata);
                        themeService.syncToExternalApps(bundle);
                        console.log("[ThemeService] Stylix seed loaded:", seed.metadata.name);
                    } else {
                        console.warn("[ThemeService] Stylix seed invalid or missing colors");
                    }
                } catch (e) {
                    console.error("[ThemeService] Failed to parse Stylix seed:", e);
                }
                stylixSeedLoader.buffer = "";
            }
        }
    }

    function loadStylixSeed() {
        // Check if colors.json exists and has a non-Stylix source before loading seed
        var colorsPath = themeService.homeDir + "/.cache/theme/colors.json";
        stylixChecker.command = ["sh", "-c", "test -f " + colorsPath + " && cat " + colorsPath + " || echo 'NONE'"];
        stylixChecker.running = true;
    }

    /**
     * Force-load the Stylix seed palette NOW, bypassing the clobber guard.
     * User-initiated "Load Stylix" action from the Manual Theme Editor: pulls
     * the seed colors into ThemeConfig + colors.json + external apps live, so
     * the editor fields populate with the extracted palette for tweaking.
     */
    function applyStylixSeedNow() {
        stylixSeedLoader.running = true;
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
            "oledClamp": themeService.isOledClampActive
        };

        themeService._writeColorsJson(Config.ThemeConfig.colors, Config.ThemeConfig.metadata);

        // Sync to external apps
        themeService.syncToExternalApps(Config.ThemeConfig.colors);

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
                oledClamp: themeService.isOledClampActive
            }
        }, true)

        themeService._writeColorsJson(bundle, Config.ThemeConfig.metadata)
        themeService.syncToExternalApps(bundle)
    }

    function _writeCustomThemes() {
        var payload = JSON.stringify(themeService.customThemes)
        var writer = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService)
        writer.command = ["sh", "-c", "printf '%s' '" + payload.replace(/'/g, "'\\''") + "' > " + themeService.customThemesPath]
        writer.onExited.connect(function(code) {
            if (code !== 0) {
                var errorMsg = "Failed to write custom themes (exit " + code + "). Custom theme may be lost.";
                console.error("[ThemeService] " + errorMsg);
                CommandService.pushLog("[ThemeService] " + errorMsg, "error");
            }
        });
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

        // kitty: write the palette to the file kitty.conf already includes
        // (include ~/.config/ngeran/theme/kitty.conf). Reload kitty (ctrl+shift+f5)
        // to apply — kitty doesn't auto-reload config.
        var kittyConf = themeService.homeDir + "/.config/ngeran/theme/kitty.conf";
        var kittyContent =
            "background " + colors.background + "\n" +
            "foreground " + colors.text + "\n" +
            "cursor " + colors.primary + "\n" +
            "selection_background " + colors.primary + "\n" +
            "selection_foreground " + colors.background + "\n" +
            "color0 "  + colors.background + "\n" +
            "color1 "  + colors.error + "\n" +
            "color2 "  + colors.success + "\n" +
            "color3 "  + colors.warning + "\n" +
            "color4 "  + colors.primary + "\n" +
            "color5 "  + colors.secondary + "\n" +
            "color6 "  + colors.info + "\n" +
            "color7 "  + colors.text + "\n" +
            "color8 "  + colors.textDim + "\n" +
            "color9 "  + colors.error + "\n" +
            "color10 " + colors.success + "\n" +
            "color11 " + colors.warning + "\n" +
            "color12 " + colors.primary + "\n" +
            "color13 " + colors.secondary + "\n" +
            "color14 " + colors.info + "\n" +
            "color15 " + colors.text + "\n";
        var kittyWriter = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService);
        kittyWriter.command = ["sh", "-c", "mkdir -p ~/.config/ngeran/theme && printf '%s' '" + kittyContent + "' > " + kittyConf + " && pkill -SIGUSR1 kitty || true"];
        kittyWriter.running = true;

        // hyprlock: write theme colors to a sourced file. Add this to the END
        // of ~/.config/hypr/hyprlock.conf:  source = ~/.config/hypr/quickshell-colors.conf
        var hyprlockFile = themeService.homeDir + "/.config/hypr/quickshell-colors.conf";
        var hyprlockContent =
            "# Managed by QuickShell ThemeService — source at END of hyprlock.conf\n" +
            "background {\n    color = rgba(" + colors.background.replace("#","") + "ff)\n}\n" +
            "input-field {\n" +
            "    inner_color = rgba(" + colors.surfaceContainer.replace("#","") + "ff)\n" +
            "    outer_color = rgba(" + colors.secondary.replace("#","") + "ff)\n" +
            "    font_color = rgba(" + colors.text.replace("#","") + "ff)\n}\n";
        var hyprlockWriter = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService);
        hyprlockWriter.command = ["sh", "-c", "mkdir -p ~/.config/hypr && printf '%s' '" + hyprlockContent + "' > " + hyprlockFile];
        hyprlockWriter.running = true;

        // Hyprland border colors: instant visual impact, applies immediately
        // Sets the active and inactive border colors to match the theme
        var hyprlandCmd = "hyprctl keyword general:col.active_border " + colors.secondary.replace("#","") + " && hyprctl keyword general:col.inactive_border " + colors.outlineVariant.replace("#","");
        var hyprlandWriter = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService);
        hyprlandWriter.command = ["sh", "-c", hyprlandCmd + " && hyprctl reload"];
        hyprlandWriter.running = true;
        console.log("[ThemeService] Applied Hyprland border colors + reloaded");

        // mako notification daemon theming (write config and reload)
        // mako uses simple color definitions in its config
        var makoConfig = themeService.homeDir + "/.config/mako/config";
        var makoContent =
            "# Managed by QuickShell ThemeService\n" +
            "default-timeout=10\n" +
            "background-color=" + colors.background + "\n" +
            "text-color=" + colors.text + "\n" +
            "border-color=" + colors.border + "\n" +
            "progress-color=" + colors.primary + "\n" +
            "background-color-d=" + colors.surface + "\n" +
            "text-color-d=" + colors.textDim + "\n" +
            "border-color-d=" + colors.outlineVariant + "\n";
        var makoWriter = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService);
        makoWriter.command = ["sh", "-c", "mkdir -p ~/.config/mako && printf '%s' '" + makoContent + "' > " + makoConfig + " && makoctl reload"];
        makoWriter.running = true;
        console.log("[ThemeService] Applied mako theme");

        // nvim (base16): write a Lua table the nvim-base16 plugin reads.
        // Lives in ~/.cache/theme (runtime-owned, like colors.json) — NOT in
        // ~/.config/nvim (whose init.lua is a home-manager nix-store symlink).
        // nvim dofile()s this on launch + on FocusGained for live reload.
        // base16 has 16 slots; quickshell tokens map 11 directly + 5 fallbacks
        // (base04/06/07/09/0F — see ~/.omni-nix/home/stylix.nix for the inverse).
        var nvimLua = "return {\n" +
            "  base00 = " + JSON.stringify(colors.background) + ",\n" +
            "  base01 = " + JSON.stringify(colors.surface) + ",\n" +
            "  base02 = " + JSON.stringify(colors.surfaceVariant) + ",\n" +
            "  base03 = " + JSON.stringify(colors.textDim) + ",\n" +
            "  base04 = " + JSON.stringify(colors.textDim) + ",\n" +   // fallback (mid comment)
            "  base05 = " + JSON.stringify(colors.text) + ",\n" +
            "  base06 = " + JSON.stringify(colors.text) + ",\n" +      // fallback (light fg)
            "  base07 = " + JSON.stringify(colors.text) + ",\n" +      // fallback (lightest fg)
            "  base08 = " + JSON.stringify(colors.error) + ",\n" +
            "  base09 = " + JSON.stringify(colors.warning) + ",\n" +   // fallback (orange-ish)
            "  base0A = " + JSON.stringify(colors.warning) + ",\n" +
            "  base0B = " + JSON.stringify(colors.success) + ",\n" +
            "  base0C = " + JSON.stringify(colors.secondary) + ",\n" +
            "  base0D = " + JSON.stringify(colors.primary) + ",\n" +
            "  base0E = " + JSON.stringify(colors.accent) + ",\n" +
            "  base0F = " + JSON.stringify(colors.error) + "\n" +       // fallback (deprecated slot)
            "}";
        var nvimPath = themeService.homeDir + "/.cache/theme/nvim-base16.lua";
        var nvimWriter = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService);
        nvimWriter.command = ["sh", "-c", "mkdir -p " + themeService.homeDir + "/.cache/theme && printf '%s' '" + nvimLua + "' > " + nvimPath];
        nvimWriter.running = true;
        console.log("[ThemeService] Wrote nvim base16 theme");
    }
}
